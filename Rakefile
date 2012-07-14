require 'rubygems'
require 'mongo'
require 'mongoid'
require 'yaml'
require 'logger'
require 'sinatra'
require 'mongoid/tree'
require 'voteable_mongo'

desc "Load the environment"
task :environment do
  env = ENV["SINATRA_ENV"] || "development"
  Sinatra::Base.environment = env
  Mongoid.load!("config/mongoid.yml")
  Mongoid.logger.level = Logger::INFO
end

namespace :db do
  task :seed => :environment do

    require_relative 'models/comment.rb'
    require_relative 'models/comment_thread.rb'
    require_relative 'models/user.rb'

    Comment.delete_all
    CommentThread.delete_all
    User.delete_all

    beginning_time = Time.now

    level_limit = YAML.load_file("config/application.yml")["level_limit"]

    user = User.create!(external_id: "1")

    def generate_comments(commentable_type, commentable_id, level_limit, user)
      5.times do
        comment_thread = CommentThread.new(
                          commentable_type: commentable_type, commentable_id: commentable_id,
                          body: "This is a post", title: "Post No.#{rand(10)}",
                          course_id: "1")
        comment_thread.author = user
        comment_thread.save!
        3.times do
          comment = Comment.new(body: "top comment", course_id: "1")
          comment.comment_thread = comment_thread
          comment.author = user
          comment.endorsed = [true, false].sample
          comment.save!
        end
        100.times do
          comment = Comment.where(comment_thread_id: comment_thread.id).reject{|c| c.depth >= level_limit}.sample
          sub_comment = Comment.new(body: "comment body", course_id: "1")
          sub_comment.author = user
          sub_comment.endorsed = [true, false].sample
          sub_comment.save!
          comment.children << sub_comment
        end
        puts "Generating a comment thread for #{commentable_type} No.#{commentable_id}"
      end
    end

    generate_comments("questions" , 1, level_limit, user)
    generate_comments("questions" , 2, level_limit, user)
    generate_comments("questions" , 3, level_limit, user)
    generate_comments("courses"   , 1, level_limit, user)
    generate_comments("lectures"  , 1, level_limit, user)
    generate_comments("lectures"  , 2, level_limit, user)
    generate_comments("lectures"  , 3, level_limit, user)
=begin
    puts "voting"
    users = []
    (1..20).each do |id|
      users << User.find_or_create_by(external_id: id.to_s)
    end

    current = 0
    total = Comment.count
    Comment.all.each do |c|
      (0...20).each do |i|
        users[i].vote(c, [:up, :down].sample)
      end
      current += 1
      puts "voted #{current}/#{total}"
    end
=end

    end_time = Time.now

    puts "Number of comments generated: #{Comment.count}"
    puts "Number of comment threads generated: #{CommentThread.count}"

    puts "Time elapsed #{(end_time - beginning_time)*1000} milliseconds"

  end
end
