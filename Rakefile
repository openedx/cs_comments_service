require 'rubygems'
require 'active_record'
require 'yaml'
require 'logger'

desc "Load the environment"
task :environment do
  env = ENV["SINATRA_ENV"] || "development"
  databases = YAML.load_file("config/database.yml")
  ActiveRecord::Base.establish_connection(databases[env])
end

namespace :db do
  desc "Migrate the database"
  task :migrate => :environment do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate("db/migrate")
  end
  task :seed => :environment do
    require_relative 'models/comment.rb'
    require_relative 'models/comment_thread.rb'
    require_relative 'models/vote.rb'
    require_relative 'models/user.rb'
    Comment.delete_all
    CommentThread.delete_all
    Vote.delete_all
    User.delete_all
    level_limit = YAML.load_file("config/application.yml")["level_limit"]

    def generate_comments(commentable_type, commentable_id, level_limit)
      comment_thread = CommentThread.create! :commentable_type => commentable_type, :commentable_id => commentable_id
      5.times do
        comment_thread.root_comments.create :body => "top comment", :title => "top #{rand(10)}", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id
      end
      10.times do
        comment = Comment.all.reject{|c| c.is_root? or c.depth  >= level_limit or c.comment_thread_id != comment_thread.id}.sample
        comment.children.create :body => "comment body", :title => "comment title #{rand(50)}", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id
      end
    end

    generate_comments("questions" , 1, level_limit)
    generate_comments("questions" , 2, level_limit)
    generate_comments("questions" , 3, level_limit)
    generate_comments("courses"   , 1, level_limit)
    generate_comments("lectures"  , 1, level_limit)
    generate_comments("lectures"  , 2, level_limit)
    generate_comments("lectures"  , 3, level_limit)

    Comment.all.reject{|c| c.is_root?}.each do |c|
      (1..20).each do |id|
        user = User.find_or_create_by_id(id)
        user.vote(c, {:direction => [:up, :down].sample})
      end
    end
  end
  
end
