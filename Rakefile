require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

application_yaml = ERB.new(File.read("config/application.yml")).result()

Tire.configure do
  url YAML.load(application_yaml)['elasticsearch_server']
end

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
  Dir[File.dirname(__FILE__) + '/models/observers/*.rb'].each {|file| require file}

  Mongoid.observers = PostReplyObserver, PostTopicObserver, AtUserObserver
  Mongoid.instantiate_observers

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

  task :reindex_search => :environment do
    Mongoid.identity_map_enabled = false

    klass = CommentThread
    ENV['CLASS'] = klass.name
    ENV['INDEX'] = new_index = klass.tire.index.name << '_' << Time.now.strftime('%Y%m%d%H%M%S')

    Rake::Task["tire:import"].invoke

    puts '[IMPORT] about to swap index'
    if a = Tire::Alias.find(klass.tire.index.name)
      puts "[IMPORT] aliases found: #{Tire::Alias.find(klass.tire.index.name).indices.to_ary.join(',')}. deleting."
      old_indices = Tire::Alias.find(klass.tire.index.name).indices
      old_indices.each do |index|
        a.indices.delete index
      end

      a.indices.add new_index
      a.save

      old_indices.each do |index|
        puts "[IMPORT] deleting index: #{index}"
        i = Tire::Index.new(index)
        i.delete if i.exists?
      end
    else
      puts "[IMPORT] no aliases found. deleting index. creating new one and setting up alias."
      klass.tire.index.delete
      a = Tire::Alias.new
      a.name(klass.tire.index.name)
      a.index(new_index)
      a.save
    end

    puts "[IMPORT] done. Index: '#{new_index}' created."
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
