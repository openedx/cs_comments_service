require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

application_yaml = ERB.new(File.read("config/application.yml")).result()

Tire.configure do
  url YAML.load(application_yaml)['elasticsearch_server']
end

LOG = Logger.new(STDERR)

desc "Load the environment"
task :environment do
  environment = ENV["SINATRA_ENV"] || "development"
  Sinatra::Base.environment = environment
  Mongoid.load!("config/mongoid.yml")
  Mongoid.logger.level = Logger::INFO
  module CommentService
    class << self; attr_accessor :config; end
  end

  CommentService.config = YAML.load(application_yaml)

  Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each {|file| require file}
  Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}
  #Dir[File.dirname(__FILE__) + '/models/observers/*.rb'].each {|file| require file}

  #Mongoid.observers = PostReplyObserver, PostTopicObserver, AtUserObserver
  #Mongoid.instantiate_observers

end

def create_test_user(id)
  User.create!(external_id: id, username: "user#{id}")
end

Dir.glob('lib/tasks/*.rake').each { |r| import r }

task :console => :environment do
  binding.pry
end

namespace :db do
  task :init => :environment do
    puts "recreating indexes..."
    [Comment, CommentThread, User, Notification, Subscription, Activity, Delayed::Backend::Mongoid::Job].each(&:remove_indexes).each(&:create_indexes)
    puts "finished"
  end

  task :clean => :environment do
    Comment.delete_all
    CommentThread.delete_all
    User.delete_all
    Notification.delete_all
    Subscription.delete_all
  end

  THREADS_PER_COMMENTABLE = 20
  TOP_COMMENTS_PER_THREAD = 3
  ADDITIONAL_COMMENTS_PER_THREAD = 5

  COURSE_ID = "MITx/6.002x/2012_Fall"

  def generate_comments_for(commentable_id, num_threads=THREADS_PER_COMMENTABLE, num_top_comments=TOP_COMMENTS_PER_THREAD, num_subcomments=ADDITIONAL_COMMENTS_PER_THREAD)
    level_limit = CommentService.config["level_limit"]


    users = User.all.to_a

    puts "Generating threads and comments for #{commentable_id}..."

    threads = []
    top_comments = []
    additional_comments = []

    num_threads.times do
      inner_top_comments = []

      comment_thread = CommentThread.new(commentable_id: commentable_id, body: Faker::Lorem.paragraphs.join("\n\n"), title: Faker::Lorem.sentence(6))
      comment_thread.author = users.sample
      comment_thread.course_id = COURSE_ID
      comment_thread.save!
      threads << comment_thread
      users.sample(3).each {|user| user.subscribe(comment_thread)}
      (1 + rand(num_top_comments)).times do
        comment = comment_thread.comments.new(body: Faker::Lorem.paragraph(2))
        comment.author = users.sample
        comment.endorsed = [true, false].sample
        comment.comment_thread = comment_thread
        comment.course_id = COURSE_ID
        comment.save!
        top_comments << comment
        inner_top_comments << comment
      end
      previous_level_comments = inner_top_comments
      (level_limit-1).times do
        current_level_comments = []
        (1 + rand(num_subcomments)).times do
          comment = previous_level_comments.sample
          sub_comment = comment.children.new(body: Faker::Lorem.paragraph(2))
          sub_comment.author = users.sample
          sub_comment.endorsed = [true, false].sample
          sub_comment.comment_thread = comment_thread
          sub_comment.course_id = COURSE_ID
          sub_comment.save!
          current_level_comments << sub_comment
        end
        previous_level_comments = current_level_comments
      end
    end

    puts "voting"

    (threads + top_comments + additional_comments).each do |c|
      users.each do |user|
        user.vote(c, [:up, :down].sample)
      end
    end
    puts "finished"
  end


  task :generate_comments, [:commentable_id, :num_threads, :num_top_comments, :num_subcomments] => :environment do |t, args|
    args.with_defaults(:num_threads => THREADS_PER_COMMENTABLE,
                       :num_top_comments=>TOP_COMMENTS_PER_THREAD,
                       :num_subcomments=> ADDITIONAL_COMMENTS_PER_THREAD)
    generate_comments_for(args[:commentable_id], args[:num_threads], args[:num_top_comments], args[:num_subcomments])

  end

  task :bulk_seed, [:num] => :environment do |t, args|
    Mongoid.configure do |config|
      config.connect_to("cs_comments_service_bulk_test")
    end
    connnection = Mongo::Connection.new("127.0.0.1", "27017")
    db = Mongo::Connection.new.db("cs_comments_service_bulk_test")

    CommentThread.create_indexes
    Comment.create_indexes
    Content.delete_all
    coll = db.collection("contents")
    args[:num].to_i.times do
      doc = {"_type" => "CommentThread", "anonymous" => [true, false].sample, "at_position_list" => [],
        "tags_array" => [],
        "comment_count" => 0, "title" => Faker::Lorem.sentence(6), "author_id" => rand(1..10).to_s,
        "body" => Faker::Lorem.paragraphs.join("\n\n"), "course_id" => COURSE_ID, "created_at" => Time.now,
        "commentable_id" => COURSE_ID, "closed" => [true, false].sample, "updated_at" => Time.now, "last_activity_at" => Time.now,
        "votes" => {"count" => 0, "down" => [], "down_count" => 0, "point" => 0, "up" => [], "up_count" => []}}
      coll.insert(doc)
    end
    Tire.index('comment_threads').delete
    CommentThread.create_elasticsearch_index
    Tire.index('comment_threads') { import CommentThread.all }
  end

  task :seed_fast => :environment do
    ADDITIONAL_COMMENTS_PER_THREAD = 20

    config = YAML.load_file("config/mongoid.yml")[Sinatra::Base.environment]["sessions"]["default"]
    connnection = Mongo::Connection.new(config["hosts"][0].split(":")[0], config["hosts"][0].split(":")[1])
    db = Mongo::Connection.new.db(config["database"])
    coll = db.collection("contents")
    Comment.delete_all
    CommentThread.each do |thread|
      ADDITIONAL_COMMENTS_PER_THREAD.times do
        doc = {"_type" => "Comment", "anonymous" => false, "at_position_list" => [],
          "author_id" => rand(1..10).to_s, "body" => Faker::Lorem.paragraphs.join("\n\n"),
          "comment_thread_id" => BSON::ObjectId.from_string(thread.id.to_s), "course_id" => COURSE_ID,
          "created_at" => Time.now,
          "endorsed" => [true, false].sample, "parent_ids" => [], "updated_at" => Time.now,
          "votes" => {"count" => 0, "down" => [], "down_count" => 0, "point" => 0, "up" => [], "up_count" => []}}
        coll.insert(doc)
      end
    end
  end

  task :seed => :environment do

    Comment.delete_all
    CommentThread.delete_all
    User.delete_all
    Notification.delete_all
    Subscription.delete_all
    Tire.index 'comment_threads' do delete end
    CommentThread.create_elasticsearch_index

    beginning_time = Time.now

    users = (1..10).map {|id| create_test_user(id)}
    # 3.times do
    #   other_user = users[1..9].sample
    #   users.first.subscribe(other_user)
    # end

    # 10.times do
    #   user = users.sample
    #   other_user = users.select{|u| u != user}.sample
    #   user.subscribe(other_user)
    # end
    generate_comments_for("video_1")
    generate_comments_for("lab_1")
    generate_comments_for("lab_2")

    end_time = Time.now

    puts "Number of comments generated: #{Comment.count}"
    puts "Number of comment threads generated: #{CommentThread.count}"

    puts "Time elapsed #{(end_time - beginning_time)*1000} milliseconds"

  end

  task :add_anonymous_to_peers => :environment do
    Content.collection.find(:anonymous_to_peers=>nil).update_all({"$set" => {'anonymous_to_peers' => false}})
  end

end


namespace :search do

  def get_es_index
    # we are using the same index for two types, which is against the
    # grain of Tire's design.  This is why this method works for both
    # comment_threads and comments.
    CommentThread.tire.index
  end

  def get_number_of_primary_shards(index_name)
    res = Tire::Configuration.client.get "#{Tire::Configuration.url}/#{index_name}/_status"
    status = JSON.parse res.body
    status["indices"].first[1]["shards"].size
  end

  def create_es_index
    # create the new index with a unique name
    new_index = Tire.index "#{Content::ES_INDEX_NAME}_#{Time.now.strftime('%Y%m%d%H%M%S')}"
    new_index.create
    LOG.info "configuring new index: #{new_index.name}"
    [CommentThread, Comment].each do |klass|
      LOG.info "applying index mappings for #{klass.name}"
      klass.put_search_index_mapping new_index
    end
    new_index
  end

  def import_from_cursor(cursor, index, opts)
    Mongoid.identity_map_enabled = true
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
      Mongoid::IdentityMap.clear
      sleep opts[:sleep_time]
      documents
    end
    LOG.info "#{index.name}: finished importing #{cnt} documents"
    cnt
  end

  def move_alias_to(name, index)
    # if there was a previous index, switch over the alias to point to the new index
    alias_ = Tire::Alias.find name
    if alias_ then
      # does the alias already point to this index?
      if alias_.indices.include? index.name then
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
    # get a reference to the model class (and make sure it's a model class with tire hooks)

    start_time = Time.now
    # create the new index with a unique name
    new_index = create_es_index
    # unless the user is forcing a rebuild, or the index does not yet exist, we
    # can do a Tire api reindex which is much faster than reimporting documents
    # from mongo.
    #
    # Checking if the index exists is tricky.  Tire automatically created an index
    # for the model class when the app loaded if one did not already exist.  However,
    # it won't create an alias, which is what our app uses.  So if the index exists
    # but not the alias, we know that it's auto-created.
    old_index = get_es_index
    alias_name = old_index.name
    alias_ = Tire::Alias.find alias_name
    if alias_.nil? then
      # edge case.
      # the alias doesn't exist, so we know the index was auto-created.
      # We will delete it and replace it with an alias.
      raise RuntimeError, 'Cannot reindex in-place, no valid source index' if in_place
      LOG.warn "deleting auto-created index to make room for the alias"
      old_index.delete
      # NOTE on the small chance that another process re-auto-creates the index
      # we just deleted before we have a chance to create the alias, this next
      # call will fail.
      move_alias_to(Content::ES_INDEX_NAME, new_index)
    end

    op = in_place ? "reindex" : "(re)build index" 
    LOG.info "preparing to #{op}"

    if in_place then
      # reindex, moving source documents directly from old index to new
      LOG.info "copying documents from original index (this may take a while!)"
      old_index.reindex new_index.name
      LOG.info "done copying!"
    else
      # fetch all the documents ever, up til start_time
      cursor = Content.where(:_type.in => ["Comment", "CommentThread"], :updated_at.lte => start_time)
      # import them to the new index
      import_from_cursor(cursor, new_index, opts)
    end

    # move the alias if necessary
    did_alias_move = move_alias_to(Content::ES_INDEX_NAME, new_index)

    if did_alias_move then
      #  Reimport any source documents that got updated since start_time,
      #  while the alias still pointed to the old index.
      #  Elasticsearch understands our document ids, so re-indexing the same 
      #  document won't create duplicates.
      LOG.info "importing any documents that changed between #{start_time} and now"
      cursor = Content.where(:_type.in => ["Comment", "CommentThread"], :updated_at.gte => start_time)
      import_from_cursor(cursor, new_index, opts)
    end
  end

  desc "Copies contents of MongoDB into Elasticsearch if updated in the last N minutes."
  task :catchup, [:minutes, :batch_size, :sleep_time] => :environment do |t, args|
    opts = batch_opts args
    the_index = get_es_index
    alias_ = Tire::Alias.find the_index.name
    # this check makes sure we are working with the index to which
    # the desired model's alias presently points.
    raise RuntimeError, "could not find live index" if alias_.nil?
    start_time = Time.now - (args[:minutes].to_i * 60)
    cursor = Content.where(:_type.in => ["Comment", "CommentThread"], :updated_at.gte => start_time)
    import_from_cursor(cursor, the_index, opts)
  end

  def batch_opts(args)
    args = args.to_hash
    { :batch_size => args[:batch_size].nil? ? 500 : args[:batch_size].to_i,
      :sleep_time => args[:sleep_time].nil? ? 0 : args[:sleep_time].to_i }
  end

  desc "Removes any data from Elasticsearch that no longer exists in MongoDB."
  task :prune, [:batch_size, :sleep_time] => :environment do |t, args|
    opts = batch_opts args
    the_index = get_es_index
    puts "pruning #{the_index.name}"
    alias_ = Tire::Alias.find the_index.name
    raise RuntimeError, "could not find live index" if alias_.nil?
    scan_size = opts[:batch_size] / get_number_of_primary_shards(the_index.name)
    cnt = 0
    [CommentThread, Comment].each do |klass|
      doc_type = klass.document_type
      # this check makes sure we are working with the index to which
      # the desired model's alias presently points.
      search = Tire::Search::Scan.new the_index.name, {size: scan_size, type: doc_type}
      search.each do |results|
        es_ids = results.map(&:id)
        mongo_ids = klass.where(:id.in => es_ids).map {|d| d.id.to_s}
        to_delete = es_ids - mongo_ids
        if to_delete.size > 0
          cnt += to_delete.size
          puts "deleting #{to_delete.size} orphaned #{doc_type} documents from elasticsearch"
          the_index.bulk_delete (to_delete).map {|v| {"type" => doc_type, "id" => v}}
        end
        puts "#{the_index.name}/#{doc_type}: processed #{search.seen} of #{search.total}"
        sleep opts[:sleep_time]
      end
    end
    puts "done pruning #{the_index.name}, deleted a total of #{cnt} orphaned documents"
  end

  desc "Rebuild the content index from MongoDB data."
  task :rebuild, [:batch_size, :sleep_time] => :environment do |t, args|
    do_reindex(batch_opts(args))
  end

  desc "Rebuild the content index from already-indexed data (in place)."
  task :reindex, [:batch_size, :sleep_time] => :environment do |t, args|
    do_reindex(batch_opts(args), true)
  end

  desc "Generate a new, empty physical index, without bringing it online."
  task :create_index => :environment do
    create_es_index
  end

end

namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear => :environment do
    Delayed::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment do
    Delayed::Worker.new(:min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY'], :queues => (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','), :quiet => false).start
  end
end

namespace :i18n do
  desc "Push source strings to Transifex for translation"
  task :push do
    sh("tx push -s")
  end

  desc "Pull translated strings from Transifex"
  task :pull do
    sh("tx pull --mode=reviewed --all --minimum-perc=1")
  end

  desc "Clean the locale directory"
  task :clean do
    sh("git clean -f locale/")
  end

  desc "Commit translated strings to the repository"
  task :commit => ["i18n:clean", "i18n:pull"] do
    sh("git add locale")
    sh("git commit -m 'Updated translations (autogenerated message)'")
  end
end
