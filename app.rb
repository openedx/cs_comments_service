require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

env_index = ARGV.index("-e")
env_arg = ARGV[env_index + 1] if env_index
env = env_arg || ENV["SINATRA_ENV"] || "development"

module CommentService
  class << self; attr_accessor :config; end
end

CommentService.config = YAML.load_file("config/application.yml")

Mongoid.load!("config/mongoid.yml")
Mongoid.logger.level = Logger::INFO

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}

delete '/api/v1/:commentable_type/:commentable_id/threads' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_initialize_by(commentable_type: commentable_type, commentable_id: commentable_id)
  commentable.destroy
  commentable.to_hash.to_json
end

get '/api/v1/:commentable_type/:commentable_id/threads' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_create_by(commentable_type: commentable_type, commentable_id: commentable_id)
  commentable.comment_threads.map{|t| t.to_hash(recursive: params["recursive"])}.to_json
end

post '/api/v1/:commentable_type/:commentable_id/threads' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_create_by(commentable_type: commentable_type, commentable_id: commentable_id)
  thread = commentable.comment_threads.new(params.slice(*%w[title body course_id]))
  thread.author = User.find_or_create_by(external_id: params["user_id"]) if params["user_id"]
  thread.save!
  thread.to_hash.to_json
end

get '/api/v1/threads/:thread_id' do |thread_id|
  thread = CommentThread.find(thread_id)
  thread.to_hash(recursive: params["recursive"]).to_json
end

put '/api/v1/threads/:thread_id' do |thread_id|
  thread = CommentThread.find(thread_id)
  thread.update_attributes!(params.slice(*%w[title body]))
  thread.to_hash.to_json
end

post '/api/v1/threads/:thread_id/comments' do |thread_id|
  thread = CommentThread.find(thread_id)
  comment = thread.comments.new(params.slice(*%w[body course_id]))
  comment.author = User.find_or_create_by(external_id: params["user_id"]) if params["user_id"]
  comment.save!
  comment.to_hash.to_json
end

delete '/api/v1/threads/:thread_id' do |thread_id|
  thread = CommentThread.find(thread_id)
  thread.destroy
  thread.to_hash.to_json
end

get '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.to_hash(recursive: params["recursive"]).to_json
end

put '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.update_attributes!(params.slice(*%w[body endorsed]))
  comment.to_hash.to_json
end

post '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  sub_comment = comment.children.new(params.slice(*%w[body course_id]))
  sub_comment.author = User.find_or_create_by(external_id: params["user_id"])
  sub_comment.save!
  sub_comment.to_hash.to_json
end

delete '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.destroy
  comment.to_hash.to_json
end

put '/api/v1/comments/:comment_id/votes' do |comment_id|
  comment = Comment.find(comment_id)
  handle_vote_for comment
end

delete '/api/v1/comments/:comment_id/votes' do |comment_id|
  comment = Comment.find(comment_id)
  handle_unvote_for comment
end

put '/api/v1/threads/:thread_id/votes' do |thread_id|
  thread = CommentThread.find(thread_id)
  handle_vote_for thread
end

delete '/api/v1/threads/:thread_id/votes' do |thread_id|
  thread = CommentThread.find(thread_id)
  handle_unvote_for thread
end

get '/api/v1/users/:user_id/notifications' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  user.notifications.map(&:to_hash).to_json
end

post '/api/v1/users/:user_id/subscriptions' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  case params["subscribed_type"]
    when "user"
      user.follow(User.find_or_create_by(external_id: params["subscribed_id"]))
    when "thread"
      user.subscribe_comment_thread(CommentThread.find(params["subscribed_id"]))
    else
      user.subscribe_commentable(Commentable.find_or_create_by(commentable_type: params["subscribed_type"], commentable_id: params["subscribed_id"]))
  end
  user.reload.to_hash.to_json
end

delete '/api/v1/users/:user_id/subscriptions' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  case params["subscribed_type"]
    when "user"
      user.unfollow(User.find_or_create_by(external_id: params["subscribed_id"]))
    when "thread"
      user.unsubscribe_comment_thread(CommentThread.find(params["subscribed_id"]))
    else
      user.unsubscribe_commentable(Commentable.find_or_create_by(commentable_type: params["subscribed_type"], commentable_id: params["subscribed_id"]))
  end
  user.reload.to_hash.to_json
end

if env.to_s == "development"
  get '/api/v1/clean' do
    Comment.delete_all
    CommentThread.delete_all
    Commentable.delete_all
    User.delete_all
    Notification.delete_all
    {}.to_json
  end
end

def handle_vote_for(obj)
  user = User.find_or_create_by(external_id: params["user_id"])
  user.vote(obj, params["value"].to_sym)
  obj.reload.to_hash.to_json
end

def handle_unvote_for(obj)
  user = User.find_or_create_by(external_id: params["user_id"])
  user.unvote(obj)
  obj.reload.to_hash.to_json
end
