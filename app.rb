require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

env_index = ARGV.index("-e")
env_arg = ARGV[env_index + 1] if env_index
environment = env_arg || ENV["SINATRA_ENV"] || "development"
RACK_ENV = environment

module CommentService
  class << self; attr_accessor :config; end
end

CommentService.config = YAML.load_file("config/application.yml")

Mongoid.load!("config/mongoid.yml")
Mongoid.logger.level = Logger::INFO

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each {|file| require file}

delete '/api/v1/:commentable_id/threads' do |commentable_id|
  commentable.comment_threads.destroy_all
  {}.to_json
end

get '/api/v1/:commentable_id/threads' do |commentable_id|
  commentable.comment_threads.map{|t| t.to_hash(recursive: params["recursive"])}.to_json
end

post '/api/v1/:commentable_id/threads' do |commentable_id|
  thread = CommentThread.new(params.slice(*%w[title body course_id]).merge(commentable_id: commentable_id))
  thread.tags = params["tags"] || ""
  thread.author = user
  thread.save!
  if params["auto_subscribe"] and author
    author.subscribe(thread)
  end
  thread.to_hash.to_json
end

get '/api/v1/threads/:thread_id' do |thread_id|
  thread.to_hash(recursive: params["recursive"]).to_json
end

put '/api/v1/threads/:thread_id' do |thread_id|
  thread.update_attributes!(params.slice(*%w[title body]))
  if params["tags"]
    thread.tags = params["tags"]
    thread.save!
  end
  thread.to_hash.to_json
end

post '/api/v1/threads/:thread_id/comments' do |thread_id|
  comment = thread.comments.new(params.slice(*%w[body course_id]))
  comment.author = user 
  comment.save!
  if params["auto_subscribe"] and author
    author.subscribe(thread)
  end
  comment.to_hash.to_json
end

delete '/api/v1/threads/:thread_id' do |thread_id|
  thread.destroy
  thread.to_hash.to_json
end

get '/api/v1/comments/:comment_id' do |comment_id|
  comment.to_hash(recursive: params["recursive"]).to_json
end

put '/api/v1/comments/:comment_id' do |comment_id|
  comment.update_attributes!(params.slice(*%w[body endorsed]))
  comment.to_hash.to_json
end

post '/api/v1/comments/:comment_id' do |comment_id|
  sub_comment = comment.children.new(params.slice(*%w[body course_id]))
  sub_comment.author = user
  sub_comment.comment_thread = comment.comment_thread
  sub_comment.save!
  sub_comment.to_hash.to_json
end

delete '/api/v1/comments/:comment_id' do |comment_id|
  comment.destroy
  comment.to_hash.to_json
end

put '/api/v1/comments/:comment_id/votes' do |comment_id|
  vote_for comment
end

delete '/api/v1/comments/:comment_id/votes' do |comment_id|
  undo_vote_for comment
end

put '/api/v1/threads/:thread_id/votes' do |thread_id|
  vote_for thread
end

delete '/api/v1/threads/:thread_id/votes' do |thread_id|
  undo_vote_for thread
end

get '/api/v1/users/:user_id' do |user_id|
  user.to_hash(complete: params["complete"]).to_json
end

get '/api/v1/users/:user_id/notifications' do |user_id|
  user.notifications.map(&:to_hash).to_json
end

post '/api/v1/users/:user_id/subscriptions' do |user_id|
  user.subscribe(source).to_hash.to_json
end

delete '/api/v1/users/:user_id/subscriptions' do |user_id|
  user.unsubscribe(source).to_hash.to_json
end

# GET /api/v1/search
# params:
#   text: text to search for
#   commentable_id: search within a commentable
#   
get '/api/v1/search' do 
  if params["text"]
    CommentThread.solr_search do
      fulltext(params["text"])
      if params["commentable_id"]
        with(:commentable_id, params["commentable_id"])
      end
    end.results.map(&:to_hash).to_json
  else
    {}.to_json
  end
end

if environment.to_s == "development"
  get '/api/v1/clean' do
    Comment.delete_all
    CommentThread.delete_all
    User.delete_all
    Notification.delete_all
    Subscription.delete_all
    {}.to_json
  end
end

error BSON::InvalidObjectId do
  error 400, "requested object not found"
end

error Mongoid::Errors::DocumentNotFound do
  error 400, "requested object not found"
end

error ValueError do
  error 400, env['sinatra.error'].message
end
