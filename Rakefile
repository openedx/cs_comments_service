require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require


desc "Load the environment"
task :environment do
  environment = ENV["SINATRA_ENV"] || "development"
  Sinatra::Base.environment = environment
  Mongoid.load!("config/mongoid.yml")
  Mongoid.logger.level = Logger::INFO
  module CommentService
    class << self; attr_accessor :config; end
  end

  CommentService.config = YAML.load_file("config/application.yml")

  Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each {|file| require file}
  Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}
  Dir[File.dirname(__FILE__) + '/models/observers/*.rb'].each {|file| require file}

  Mongoid.observers = PostReplyObserver, PostTopicObserver, AtUserObserver
  Mongoid.instantiate_observers

end

def create_test_user(id)
  User.create!(external_id: id, username: "user#{id}", email: "user#{id}@test.com")
end

namespace :test do
  task :nested_comments => :environment do
    puts "checking"
    50.times do
      Comment.delete_all
      CommentThread.delete_all
      User.delete_all
      Notification.delete_all
      Subscription.delete_all
      
      user = create_test_user(1)

      comment_thread = CommentThread.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1", commentable_id: "question_1")
      comment_thread.author = user
      comment_thread.save!

      comment = comment_thread.comments.new(body: "this problem is so easy", course_id: "1")
      comment.author = user
      comment.save!
      comment1 = comment.children.new(body: "not for me!", course_id: "1")
      comment1.author = user
      comment1.comment_thread = comment_thread
      comment1.save!
      comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
      comment2.author = user
      comment2.comment_thread = comment_thread
      comment2.save!

      children = comment_thread.root_comments.first.to_hash(recursive: true)["children"]
      if children.length == 2
        pp comment_thread.to_hash(recursive: true)
        pp comment_thread.root_comments.first.descendants_and_self.to_a
        puts "error!"
        break
      end
      puts "passed once"
    end
    puts "passed"
  end
end

task :console => :environment do
  binding.pry
end

namespace :db do
  task :init => :environment do
    puts "creating indexes..."
    Comment.create_indexes
    CommentThread.create_indexes
    User.create_indexes
    Notification.create_indexes
    Subscription.create_indexes
    Delayed::Backend::Mongoid::Job.create_indexes
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
  TOP_COMMENTS_PER_THREAD = 4
  ADDITIONAL_COMMENTS_PER_THREAD = 20

  COURSE_ID = "MITx/6.002x/2012_Fall"

  def generate_comments_for(commentable_id)
    level_limit = YAML.load_file("config/application.yml")["level_limit"]

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

    THREADS_PER_COMMENTABLE.times do
      inner_top_comments = []

      comment_thread = CommentThread.new(commentable_id: commentable_id, body: Faker::Lorem.paragraphs.join("\n\n"), title: Faker::Lorem.sentence(6))
      comment_thread.author = users.sample
      comment_thread.tags = tag_seeds.sort_by{rand}[0..2].join(",")
      comment_thread.course_id = COURSE_ID
      comment_thread.save!
      threads << comment_thread
      users.sample(3).each {|user| user.subscribe(comment_thread)}
      (1 + rand(TOP_COMMENTS_PER_THREAD)).times do
        comment = comment_thread.comments.new(body: Faker::Lorem.paragraph(2))
        comment.author = users.sample
        comment.endorsed = [true, false].sample
        comment.comment_thread = comment_thread
        comment.course_id = COURSE_ID
        comment.save!
        top_comments << comment
        inner_top_comments << comment
      end
      (1 + rand(ADDITIONAL_COMMENTS_PER_THREAD)).times do
        comment = inner_top_comments.sample
        sub_comment = comment.children.new(body: Faker::Lorem.paragraph(2))
        sub_comment.author = users.sample
        sub_comment.endorsed = [true, false].sample
        sub_comment.comment_thread = comment_thread
        sub_comment.course_id = COURSE_ID
        sub_comment.save!
        additional_comments << sub_comment
      end
    end

    # puts "voting"

    # (threads + top_comments + additional_comments).each do |c|
    #   users.each do |user|
    #     user.vote(c, [:up, :down].sample)
    #   end
    # end
    puts "finished"
  end


  task :generate_comments, [:commentable_id] => :environment do |t, args|

    generate_comments_for(args[:commentable_id])

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
end

# copied from https://github.com/sunspot/sunspot/blob/master/sunspot_solr/lib/sunspot/solr/tasks.rb
namespace :sunspot do
  namespace :solr do
    desc 'Start the Solr instance'
    task :start => :environment do
      case RUBY_PLATFORM
      when /w(in)?32$/, /java$/
        abort("This command is not supported on #{RUBY_PLATFORM}. " +
              "Use rake sunspot:solr:run to run Solr in the foreground.")
      end

      Sunspot::Solr::Server.new.start

      puts "Successfully started Solr ..."
    end

    desc 'Run the Solr instance in the foreground'
    task :run => :environment do
      Sunspot::Solr::Server.new.run
    end

    desc 'Stop the Solr instance'
    task :stop => :environment do
      case RUBY_PLATFORM
      when /w(in)?32$/, /java$/
        abort("This command is not supported on #{RUBY_PLATFORM}. " +
              "Use rake sunspot:solr:run to run Solr in the foreground.")
      end

      Sunspot::Solr::Server.new.stop

      puts "Successfully stopped Solr ..."
    end

    desc 'Restart the Solr instance'
    task :restart => :environment do
      case RUBY_PLATFORM
      when /w(in)?32$/, /java$/
        abort("This command is not supported on #{RUBY_PLATFORM}. " +
              "Use rake sunspot:solr:run to run Solr in the foreground.")
      end

      Sunspot::Solr::Server.new.stop
      Sunspot::Solr::Server.new.start

      puts "Successfully restarted Solr ..."
    end

  end

  task :commit => :environment do
    Sunspot.commit
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
