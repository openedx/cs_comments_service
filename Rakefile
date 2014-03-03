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
  User.create!(external_id: id, username: "user#{id}", email: "user#{id}@test.com")
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
    CommentThread.recalculate_all_context_tag_weights!
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

    tag_seeds = [
      "artificial-intelligence",
      "random rant",
      "c++",
      "c#",
      "java-sucks",
      "2012",
    ]

    users = User.all.to_a

    puts "Generating threads and comments for #{commentable_id}..."

    threads = []
    top_comments = []
    additional_comments = []

    num_threads.times do
      inner_top_comments = []

      comment_thread = CommentThread.new(commentable_id: commentable_id, body: Faker::Lorem.paragraphs.join("\n\n"), title: Faker::Lorem.sentence(6))
      comment_thread.author = users.sample
      comment_thread.tags = tag_seeds.sort_by{rand}[0..2].join(",")
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
    binding.pry
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
    CommentThread.recalculate_all_context_tag_weights!
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

  def create_index_for_class(klass)
    # create the new index with a unique name
    new_index = Tire.index klass.tire.index.name << '_' << Time.now.strftime('%Y%m%d%H%M%S')
    LOG.info "configuring new index: #{new_index.name}"
    # apply the proper mapping and settings to the new index
    new_index.create :mappings => klass.tire.mapping_to_hash, :settings => klass.tire.settings
    new_index
  end

  def import_from_cursor(cursor, index, page_size)
    tot = cursor.count
    cnt = 0
    t = Time.now
    index.import cursor, {:method => :paginate, :per_page => page_size} do |documents|
      # GC.start call is backport of memory leak fix in more recent vers. of tire
      # see https://github.com/karmi/tire/pull/658
      GC.start 
      if cnt % 1000 == 0 then
        elapsed_secs = (Time.now - t).round(2)
        pct_complete = (100 * (cnt/tot.to_f)).round(2)
        LOG.info "#{index.name}: imported #{cnt} of #{tot} (#{pct_complete}% complete after #{elapsed_secs} seconds)"
      end
      cnt += documents.length
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

  def do_reindex (classname, force_rebuild=false)
    # get a reference to the model class (and make sure it's a model class with tire hooks)
    klass = CommentService.const_get(classname)
    raise RuntimeError unless klass.instance_of? Class
    raise RuntimeError unless klass.respond_to? "tire"

    t1 = Time.now # we will need to refer back to this point in time later...
    # create the new index with a unique name
    new_index = create_index_for_class(klass)
    # unless the user is forcing a rebuild, or the index does not yet exist, we
    # can do a Tire api reindex which is much faster than reimporting documents
    # from mongo.
    #
    # Checking if the index exists is tricky.  Tire automatically created an index
    # for the model class when the app loaded if one did not already exist.  However,
    # it won't create an alias, which is what our app uses.  So if the index exists
    # but not the alias, we know that it's auto-created.
    old_index = klass.tire.index
    alias_name = old_index.name
    alias_ = Tire::Alias.find alias_name
    if alias_.nil? then
      # the alias doesn't exist, so we know the index was auto-created.
      # We will delete it and replace it with an alias.
      is_rebuild = true
      old_index.delete
      # NOTE on the small chance that another process re-auto-creates the index
      # we just deleted before we have a chance to create the alias, this next
      # call will fail.
      move_alias_to(alias_name, new_index)
    else
      is_rebuild = force_rebuild
    end

    op = is_rebuild ? "(re)build index for" : "reindex" 
    LOG.info "preparing to #{op} CommentService::#{classname}"

    # ensure there's no identity mapping or caching going on while we do this
    Mongoid.identity_map_enabled = false
    Mongoid.unit_of_work(disable: :all) do

      if is_rebuild then
        # fetch all the documents ever, up til t1
        cursor = klass.where(:updated_at.lte => t1)
        # import them to the new index
        import_from_cursor(cursor, new_index, 200)
      else
        # reindex, moving source documents directly from old index to new
        LOG.info "copying documents from original index (this may take a while!)"
        old_index.reindex new_index.name
        LOG.info "done copying!"
      end

      # move the alias if necessary
      did_alias_move = move_alias_to(klass.tire.index.name, new_index)
      t2 = Time.now

      if did_alias_move then
        #  Reimport any source documents that got updated between t1 and t2,
        #  while the alias still pointed to the old index
        LOG.info "importing any documents that changed between #{t1} and #{t2}" 
        cursor = klass.where(:updated_at.gte => t1, :updated_at.lte => t2)
        import_from_cursor(cursor, new_index, 200)
      end
    end

  end

  task :rebuild, [:classname] => :environment do |t, args|
    do_reindex(args[:classname], true)
  end

  task :reindex, [:classname] => :environment do |t, args|
    do_reindex(args[:classname])
  end

  task :resync, [:classname, :hours] => :environment do |t, args|
    klass = CommentService.const_get(args[:classname])
    raise RuntimeError unless klass.instance_of? Class
    raise RuntimeError unless klass.respond_to? "tire"
    the_index = klass.tire.index
    alias_ = Tire::Alias.find the_index.name
    # this check makes sure we are working with the index to which
    # the desired model's alias presently points.
    raise RuntimeError if alias_.nil?
    t2 = Time.now
    t1 = t2 - (args[:hours].to_i * 3600)
    cursor = klass.where(:updated_at.gte => t1, :updated_at.lte => t2)
    import_from_cursor(cursor, the_index, 200)
  end

  task :reindex_search => :environment do
    do_reindex("CommentThread")
    do_reindex("Comment")
  end

  task :add_anonymous_to_peers => :environment do
    Content.collection.find(:anonymous_to_peers=>nil).update_all({"$set" => {'anonymous_to_peers' => false}})
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
