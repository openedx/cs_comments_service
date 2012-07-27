require File.join(File.dirname(__FILE__), '..', 'app')

require 'sinatra'
require 'rack/test'
require 'yajl'

# setup test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false

Delayed::Worker.delay_jobs = false

def app
  Sinatra::Application
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

def parse(text)
  Yajl::Parser.parse text
end

def init_without_subscriptions
  Comment.delete_all
  CommentThread.delete_all
  User.delete_all
  Notification.delete_all
  Subscription.delete_all
  
  commentable = Commentable.new("question_1")

  user = User.create!(external_id: "1")

  thread = CommentThread.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1", commentable_id: commentable.id)
  thread.author = user
  thread.save!
  user.subscribe(thread)

  comment = thread.comments.new(body: "this problem is so easy", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "not for me!", course_id: "1")
  comment1.author = user
  comment1.comment_thread = thread
  comment1.save!
  comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
  comment2.author = user
  comment2.comment_thread = thread
  comment2.save!

  comment = thread.comments.new(body: "see the textbook on page 69. it's quite similar", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "thank you!", course_id: "1")
  comment1.author = user
  comment1.comment_thread = thread
  comment1.save!

  thread = CommentThread.new(title: "This problem is wrong", body: "it is unsolvable", course_id: "2", commentable_id: commentable.id)
  thread.author = user
  thread.save!
  user.subscribe(thread)

  comment = thread.comments.new(body: "how do you know?", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "because blablabla", course_id: "1")
  comment1.author = user
  comment1.comment_thread = thread
  comment1.save!
  comment = thread.comments.new(body: "no wonder I can't solve it", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "+1", course_id: "1")
  comment1.author = user
  comment1.comment_thread = thread
  comment1.save!

  users = (2..10).map{|id| User.find_or_create_by(external_id: id.to_s)}

  Comment.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users.each {|user| user.vote(c, [:up, :down].sample)}
  end

  CommentThread.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users.each {|user| user.vote(c, [:up, :down].sample)}
  end

end

def init_with_subscriptions
  Comment.delete_all
  CommentThread.delete_all
  User.delete_all
  Notification.delete_all
  Subscription.delete_all

  user1 = User.create!(external_id: "1")
  user2 = User.create!(external_id: "2")

  user2.subscribe(user1)

  commentable = Commentable.new("question_1")
  user1.subscribe(commentable)
  user2.subscribe(commentable)

  thread = CommentThread.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1", commentable_id: commentable.id)
  thread.author = user1
  user1.subscribe(thread)
  user2.subscribe(thread)
  thread.save!

  thread = thread.reload

  comment = thread.comments.new(body: "this problem is so easy", course_id: "1")
  comment.author = user2
  comment.save!
  comment1 = comment.children.new(body: "not for me!", course_id: "1")
  comment1.author = user1
  comment1.comment_thread = thread
  comment1.save!
  comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
  comment2.author = user2
  comment2.comment_thread = thread
  comment2.save!

  thread = CommentThread.new(title: "This problem is wrong", body: "it is unsolvable", course_id: "2", commentable_id: commentable.id)
  thread.author = user2
  user2.subscribe(thread)
  thread.save!
end
