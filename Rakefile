require 'rubygems'
require 'mongo'
require 'mongoid'
require 'yaml'
require 'logger'
require 'active_support/all'
require 'sinatra'
require 'mongoid/tree'
require 'voteable_mongo'
require './lib/watchable'
require './lib/followable'

desc "Load the environment"
task :environment do
  env = ENV["SINATRA_ENV"] || "development"
  Sinatra::Base.environment = env
  Mongoid.load!("config/mongoid.yml")
  Mongoid.logger.level = Logger::INFO
end

namespace :db do
  task :seed => :environment do

    require './models/comment.rb'
    require './models/comment_thread.rb'
    require './models/user.rb'
    require './models/commentable.rb'

    Commentable.delete_all
    Comment.delete_all
    CommentThread.delete_all
    User.delete_all

    beginning_time = Time.now

    level_limit = YAML.load_file("config/application.yml")["level_limit"]

    user = User.create!(external_id: "1")

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
