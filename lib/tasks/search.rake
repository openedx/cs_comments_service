require 'task_helpers'

namespace :search do
  def import_from_cursor(cursor, index, opts)
    tot = cursor.count
    cnt = 0
    t = Time.now
    index.import cursor, {:method => :paginate, :per_page => opts[:batch_size]} do |documents|
      if cnt % opts[:batch_size] == 0 then
        elapsed_secs = (Time.now - t).round(2)
        pct_complete = (100 * (cnt/tot.to_f)).round(2)
        LOG.info "#{index.name}: imported #{cnt} of #{tot} (#{pct_complete}% complete after #{elapsed_secs} seconds)"
      end
      cnt += documents.length
      sleep opts[:sleep_time]
      documents
    end
    LOG.info "#{index.name}: finished importing #{cnt} documents"
    cnt
  end

  def move_alias_to(name, index)
    # if there was a previous index, switch over the alias to point to the new index
    alias_ = Tire::Alias.find name
    if alias_
      # does the alias already point to this index?
      if alias_.indices.include? index.name
        return false
      end
      # remove the alias from wherever it points to now
      LOG.info "alias already exists (will move): #{alias_.indices.to_ary.join(',')}"
      alias_.indices.each do |old_index_name|
        alias_.indices.delete old_index_name unless old_index_name == name
      end
    else
      # create the alias
      LOG.info "alias \"#{name}\" does not yet exist - creating."
      alias_ = Tire::Alias.new :name => name
    end
    # point the alias at our new index
    alias_.indices.add index.name
    alias_.save
    LOG.info "alias \"#{name}\" now points to index #{index.name}."
    true
  end

  def do_reindex (opts, in_place=false)
    start_time = Time.now

    # create the new index with a unique name
    new_index = TaskHelpers::ElasticsearchHelper.create_index

    # unless the user is forcing a rebuild, or the index does not yet exist, we
    # can do a Tire api reindex which is much faster than reimporting documents
    # from mongo.
    #
    # Checking if the index exists is tricky.  Tire automatically created an index
    # for the model class when the app loaded if one did not already exist.  However,
    # it won't create an alias, which is what our app uses.  So if the index exists
    # but not the alias, we know that it's auto-created.
    old_index = TaskHelpers::ElasticsearchHelper.get_index
    alias_name = old_index.name
    alias_ = Tire::Alias.find alias_name
    if alias_.nil?
      # edge case.
      # the alias doesn't exist, so we know the index was auto-created.
      # We will delete it and replace it with an alias.
      raise RuntimeError, 'Cannot reindex in-place, no valid source index' if in_place
      LOG.warn 'deleting auto-created index to make room for the alias'
      old_index.delete
      # NOTE on the small chance that another process re-auto-creates the index
      # we just deleted before we have a chance to create the alias, this next
      # call will fail.
      move_alias_to(Content::ES_INDEX_NAME, new_index_name)
    end

    op = in_place ? 'reindex' : '(re)build index'
    LOG.info "preparing to #{op}"

    content_types = %w(Comment CommentThread)
    if in_place
      # reindex, moving source documents directly from old index to new
      LOG.info 'copying documents from original index (this may take a while!)'
      old_index.reindex new_index.name
      LOG.info 'done copying!'
    else
      # fetch all the documents ever, up til start_time
      cursor = Content.where(:_type.in => content_types, :updated_at.lte => start_time)
      # import them to the new index
      import_from_cursor(cursor, new_index, opts)
    end

    # move the alias if necessary
    did_alias_move = move_alias_to(Content::ES_INDEX_NAME, new_index)

    if did_alias_move
      #  Reimport any source documents that got updated since start_time,
      #  while the alias still pointed to the old index.
      #  Elasticsearch understands our document ids, so re-indexing the same
      #  document won't create duplicates.
      LOG.info "importing any documents that changed between #{start_time} and now"
      cursor = Content.where(:_type.in => content_types, :updated_at.gte => start_time)
      import_from_cursor(cursor, new_index, opts)
    end
  end

  desc 'Copies contents of MongoDB into Elasticsearch if updated in the last N minutes.'
  task :catchup, [:minutes, :batch_size, :sleep_time] => :environment do |t, args|
    opts = batch_opts args
    the_index = TaskHelpers::ElasticsearchHelper.get_index
    alias_ = Tire::Alias.find the_index.name
    # this check makes sure we are working with the index to which
    # the desired model's alias presently points.
    raise RuntimeError, "could not find live index" if alias_.nil?
    start_time = Time.now - (args[:minutes].to_i * 60)
    cursor = Content.where(:_type.in => %w(Comment CommentThread), :updated_at.gte => start_time)
    import_from_cursor(cursor, the_index, opts)
  end

  def batch_opts(args)
    args = args.to_hash
    {:batch_size => args[:batch_size].nil? ? 500 : args[:batch_size].to_i,
     :sleep_time => args[:sleep_time].nil? ? 0 : args[:sleep_time].to_i}
  end

  desc 'Removes any data from Elasticsearch that no longer exists in MongoDB.'
  task :prune, [:batch_size, :sleep_time] => :environment do |t, args|
    opts = batch_opts args
    the_index = TaskHelpers::ElasticsearchHelper.get_index
    puts "pruning #{the_index.name}"
    alias_ = Tire::Alias.find the_index.name
    raise RuntimeError, 'could not find live index' if alias_.nil?
    scan_size = opts[:batch_size] / TaskHelpers::ElasticsearchHelper.get_index_shard_count(the_index.name)
    cnt = 0
    [CommentThread, Comment].each do |klass|
      doc_type = klass.document_type
      # this check makes sure we are working with the index to which
      # the desired model's alias presently points.
      search = Tire::Search::Scan.new the_index.name, {size: scan_size, type: doc_type}
      search.each do |results|
        es_ids = results.map(&:id)
        mongo_ids = klass.where(:id.in => es_ids).map { |d| d.id.to_s }
        to_delete = es_ids - mongo_ids
        if to_delete.size > 0
          cnt += to_delete.size
          puts "deleting #{to_delete.size} orphaned #{doc_type} documents from elasticsearch"
          the_index.bulk_delete (to_delete).map { |v| {"type" => doc_type, "id" => v} }
        end
        puts "#{the_index.name}/#{doc_type}: processed #{search.seen} of #{search.total}"
        sleep opts[:sleep_time]
      end
    end
    puts "done pruning #{the_index.name}, deleted a total of #{cnt} orphaned documents"
  end

  desc 'Rebuild the content index from MongoDB data.'
  task :rebuild, [:batch_size, :sleep_time] => :environment do |t, args|
    do_reindex(batch_opts(args))
  end

  desc 'Rebuild the content index from already-indexed data (in place).'
  task :reindex, [:batch_size, :sleep_time] => :environment do |t, args|
    do_reindex(batch_opts(args), true)
  end

  desc 'Generate a new, empty physical index, without bringing it online.'
  task :create_index => :environment do
    TaskHelpers::ElasticsearchHelper.create_index
  end
end
