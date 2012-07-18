require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require


desc "Load the environment"
task :environment do
  env = ENV["SINATRA_ENV"] || "development"
  Sinatra::Base.environment = env
  Mongoid.load!("config/mongoid.yml")
  Mongoid.logger.level = Logger::INFO
  module CommentService
    class << self; attr_accessor :config; end
  end

  CommentService.config = YAML.load_file("config/application.yml")
  Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}
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
      
      user = User.create!(external_id: "1")

      comment_thread = CommentThread.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1", commentable_id: "question_1")
      comment_thread.author = user
      comment_thread.save!

      comment = comment_thread.comments.new(body: "this problem is so easy", course_id: "1")
      comment.author = user
      comment.save!
      comment1 = comment.children.new(body: "not for me!", course_id: "1")
      comment1.author = user
      comment1.save!
      comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
      comment2.author = user
      comment2.save!

      children = comment_thread.comments.first.to_hash(recursive: true)["children"]
      if children.length == 2
        pp comment_thread.to_hash(recursive: true)
        pp comment_thread.comments.first.descendants_and_self.to_a
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

  task :seed => :environment do

    Comment.delete_all
    CommentThread.delete_all
    User.delete_all
    Notification.delete_all
    Subscription.delete_all

    beginning_time = Time.now

    level_limit = YAML.load_file("config/application.yml")["level_limit"]

    users = (1..10).map {|id| User.find_or_create_by(external_id: id.to_s)}

    10.times do
      users.sample.subscribe(users.sample)
    end

    THREAD_SEEDS = [
      {title: "This is really interesting", body: "best I've ever seen!"},
      {title: "We can probably make this better", body: "Let's do it"},
      {title: "I don't know where to start", body: "Can anyone help me?"},
      {title: "I'm here!", body: "Haha I'm the first one who discovered this"},
      {title: "I need five threads but I don't know where to put here", body: "So I'll just leave it this way"},
    ]

    COMMENT_BODY_SEEDS = [
      "dude I don't know what you're talking about",
      "hi I'm Jack",
      "hi just sent you a message",
      "let's discuss this further",
      "can't agree more",
      "haha",
      "lol",
    ]
    
    def generate_comments(commentable_id, level_limit, users)
      THREAD_SEEDS.each do |thread_seed|
        comment_thread = CommentThread.new(commentable_id: commentable_id, body: thread_seed[:body], title: thread_seed[:title], course_id: "1")
        comment_thread.author = users.sample
        comment_thread.save!
        3.times do
          comment = comment_thread.comments.new(body: COMMENT_BODY_SEEDS.sample, course_id: "1")
          comment.author = users.sample
          comment.endorsed = [true, false].sample
          comment.save!
        end
        10.times do
          comment = Comment.where(comment_thread_id: comment_thread.id).reject{|c| c.depth >= level_limit}.sample
          sub_comment = comment.children.new(body: COMMENT_BODY_SEEDS.sample, course_id: "1")
          sub_comment.author = users.sample
          sub_comment.endorsed = [true, false].sample
          sub_comment.save!
        end
        puts "Generating a comment thread for #{commentable_id}"
      end
    end

    generate_comments("question_1", level_limit, users)
    generate_comments("question_2", level_limit, users)
    generate_comments("course_1", level_limit, users)
    generate_comments("video_1", level_limit, users)
    generate_comments("video_2", level_limit, users)
    generate_comments("lab_1", level_limit, users)
    generate_comments("lab_2", level_limit, users)

    puts "voting"
    users = []
    (1..10).each do |id|
      users << User.find_or_create_by(external_id: id.to_s)
    end

    CommentThread.all.each do |c|
      (0...10).each do |i|
        users[i].vote(c, [:up, :down].sample)
      end
    end

    Comment.all.each do |c|
      (0...10).each do |i|
        users[i].vote(c, [:up, :down].sample)
      end
    end

    end_time = Time.now

    puts "Number of comments generated: #{Comment.count}"
    puts "Number of comment threads generated: #{CommentThread.count}"

    puts "Time elapsed #{(end_time - beginning_time)*1000} milliseconds"

  end
end
