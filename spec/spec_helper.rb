ENV["SINATRA_ENV"] = "test"

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

Mongoid.configure do |config|
  config.connect_to "cs_comments_service_test"
end

def parse(text)
  Yajl::Parser.parse text
end

def create_test_user(id)
  User.create!(external_id: id.to_s, username: "user#{id}", email: "user#{id}@test.com")
end

def init_without_subscriptions
  Comment.delete_all
  CommentThread.delete_all
  CommentThread.recalculate_all_context_tag_weights!
  User.delete_all
  Notification.delete_all
  Subscription.delete_all
  Tire.index 'comment_threads' do delete end
  CommentThread.create_elasticsearch_index
  
  commentable = Commentable.new("question_1")

  user = create_test_user(1)

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

  users = (2..10).map{|id| create_test_user(id)}

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
  CommentThread.recalculate_all_context_tag_weights!
  User.delete_all
  Notification.delete_all
  Subscription.delete_all

  Tire.index 'comment_threads' do delete end
  CommentThread.create_elasticsearch_index

  user1 = create_test_user(1)
  user2 = create_test_user(2)

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

  thread = CommentThread.new(title: "I don't know what to say", body: "lol", course_id: "2", commentable_id: "something else")
  thread.author = user1
  thread.save!
end
