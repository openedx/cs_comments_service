require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}

desc "Load the environment"
task :environment do
  env = ENV["SINATRA_ENV"] || "development"
  Sinatra::Base.environment = env
  Mongoid.load!("config/mongoid.yml")
  Mongoid.logger.level = Logger::INFO
end

namespace :test do
  task :check_nested_comments => :environment do
    puts "checking"
    50.times do
      Comment.delete_all
      CommentThread.delete_all
      Commentable.delete_all
      User.delete_all
      Feed.delete_all
      
      commentable = Commentable.create!(commentable_type: "questions", commentable_id: "1")

      user = User.create!(id: "1")

      comment_thread = commentable.comment_threads.create!(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1")
      comment_thread.author = user
      comment_thread.save!

      comment = comment_thread.comments.create!(body: "this problem is so easy", course_id: "1")
      comment.author = user
      comment.save!
      comment1 = comment.children.create!(body: "not for me!", course_id: "1")
      comment1.author = user
      comment1.save!
      comment2 = comment1.children.create!(body: "not for me neither!", course_id: "1")
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

namespace :db do
  task :init => :environment do
    puts "creating indexes..."
    Comment.create_indexes
    CommentThread.create_indexes
    User.create_indexes
    Commentable.create_indexes
    Feed.create_indexes
    Delayed::Backend::Mongoid::Job.create_indexes
    puts "finished"
  end

  task :seed => :environment do

    Commentable.delete_all
    Comment.delete_all
    CommentThread.delete_all
    User.delete_all

    beginning_time = Time.now

    level_limit = YAML.load_file("config/application.yml")["level_limit"]

    user = User.create!(id: "1")

    def generate_comments(commentable_type, commentable_id, level_limit, user)
      commentable = Commentable.create!(commentable_type: commentable_type, commentable_id: commentable_id)
      5.times do
        comment_thread = commentable.comment_threads.new(
                          commentable_type: commentable_type, commentable_id: commentable_id,
                          body: "This is a post", title: "Post No.#{rand(10)}",
                          course_id: "1")
        comment_thread.author = user
        comment_thread.save!
        3.times do
          comment = comment_thread.comments.new(body: "top comment", course_id: "1")
          comment.author = user
          comment.endorsed = [true, false].sample
          comment.save!
        end
        10.times do
          comment = Comment.where(comment_thread_id: comment_thread.id).reject{|c| c.depth >= level_limit}.sample
          sub_comment = comment.children.new(body: "comment body", course_id: "1")
          sub_comment.author = user
          sub_comment.endorsed = [true, false].sample
          sub_comment.save!
        end
        puts "Generating a comment thread for #{commentable_type} No.#{commentable_id}"
      end
    end

    generate_comments("questions" , 1, level_limit, user)
    generate_comments("questions" , 2, level_limit, user)
    generate_comments("courses"   , 1, level_limit, user)
    generate_comments("lectures"  , 1, level_limit, user)
    generate_comments("lectures"  , 2, level_limit, user)

    puts "voting"
    users = []
    (1..10).each do |id|
      users << User.find_or_create_by(id: id.to_s)
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
