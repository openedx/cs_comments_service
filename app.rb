require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}

env_index = ARGV.index("-e")
env_arg = ARGV[env_index + 1] if env_index
env = env_arg || ENV["SINATRA_ENV"] || "development"

Mongoid.load!("config/mongoid.yml")
Mongoid.logger.level = Logger::INFO

config = YAML.load_file("config/application.yml")

# DELETE /api/v1/commentables/:commentable_type/:commentable_id

# GET /api/v1/commentables/:commentable_type/:commentable_id/comment_threads
# POST /api/v1/commentables/:commentable_type/:commentable_id/comment_threads
#
# GET /api/v1/comment_threads/:comment_thread_id
# PUT /api/v1/comment_threads/:comment_thread_id
# POST /api/v1/comment_threads/:comment_thread_id/comments
# DELETE /api/v1/comment_threads/:comment_thread_id
#
# GET /api/v1/comments/:comment_id
# PUT /api/v1/comments/:comment_id
# POST /api/v1/comments/:comment_id
# DELETE /api/v1/comments/:comment_id
#
# PUT /api/v1/votes/comments/:comment_id/users/:user_id
# DELETE /api/v1/votes/comments/:comment_id/users/:user_id
#
# PUT /api/v1/votes/comment_threads/:comment_thread_id/users/:user_id
# DELETE /api/v1/votes/comment_threads/:comment_thread_id/users/:user_id
#
# GET /api/v1/users/:user_id/feeds
# POST /api/v1/users/:user_id/follow
# POST /api/v1/users/:user_id/unfollow
# POST /api/v1/users/:user_id/watch/commentable
# POST /api/v1/users/:user_id/unwatch/commentable
# POST /api/v1/users/:user_id/watch/comment_thread
# POST /api/v1/users/:user_id/unwatch/comment_thread
#
#
#

# DELETE /api/v1/commentables/:commentable_type/:commentable_id
# delete the commentable object and all of its associated comment threads and comments

delete '/api/v1/commentables/:commentable_type/:commentable_id' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_initialize_by(commentable_type: commentable_type, commentable_id: commentable_id)
  commentable.destroy
  commentable.to_hash.to_json
end

# GET /api/v1/commentables/:commentable_type/:commentable_id/comment_threads
# get all comment threads associated with a commentable object
# additional parameters accepted: recursive

get '/api/v1/commentables/:commentable_type/:commentable_id/comment_threads' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_create_by(commentable_type: commentable_type, commentable_id: commentable_id)
  commentable.comment_threads.map{|t| t.to_hash(recursive: params["recursive"])}.to_json
end

# POST /api/v1/commentables/:commentable_type/:commentable_id/comment_threads
# create a new comment thread for the commentable object

post '/api/v1/commentables/:commentable_type/:commentable_id/comment_threads' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_create_by(commentable_type: commentable_type, commentable_id: commentable_id)
  comment_thread = commentable.comment_threads.new(params.slice(*%w[title body course_id]))
  comment_thread.author = User.find_or_create_by(external_id: params["user_id"])
  comment_thread.save!
  comment_thread.to_hash.to_json
end

# GET /api/v1/comment_threads/:comment_thread_id
# get information of a single comment thread
# additional parameters accepted: recursive

get '/api/v1/comment_threads/:comment_thread_id' do |comment_thread_id|
  comment_thread = CommentThread.find(comment_thread_id)
  comment_thread.to_hash(recursive: params["recursive"]).to_json
end

# PUT /api/v1/comment_threads/:comment_thread_id
# update information of comment thread

put '/api/v1/comment_threads/:comment_thread_id' do |comment_thread_id|
  comment_thread = CommentThread.find(comment_thread_id)
  comment_thread.update_attributes!(params.slice(*%w[title body]))
  comment_thread.to_hash.to_json
end

# POST /api/v1/comment_threads/:comment_thread_id/comments
# create a comment to the comment thread
post '/api/v1/comment_threads/:comment_thread_id/comments' do |comment_thread_id|
  comment_thread = CommentThread.find(comment_thread_id)
  comment = comment_thread.comments.new(params.slice(*%w[body course_id]))
  comment.author = User.find_or_create_by(external_id: params["user_id"])
  comment.save!
  comment.to_hash.to_json
end

# DELETE /api/v1/comment_threads/:comment_thread_id
# delete the comment thread and its comments

delete '/api/v1/comment_threads/:comment_thread_id' do |comment_thread_id|
  comment_thread = CommentThread.find(comment_thread_id)
  comment_thread.destroy
  comment_thread.to_hash.to_json
end

# GET /api/v1/comments/:comment_id
# retrieve information of a single comment
# additional parameters accepted: recursive

get '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.to_hash(recursive: params["recursive"]).to_json
end

# PUT /api/v1/comments/:comment_id
# update information of the comment

put '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.update_attributes!(params.slice(*%w[body endorsed]))
  comment.to_hash.to_json
end

# POST /api/v1/comments/:comment_id
# create a sub comment to the comment

post '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  sub_comment = comment.children.new(params.slice(*%w[body course_id]))
  sub_comment.author = User.find_or_create_by(external_id: params["user_id"])
  sub_comment.save!
  sub_comment.to_hash.to_json
end

# DELETE /api/v1/comments/:comment_id
# delete the comment and its sub comments

delete '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.destroy
  comment.to_hash.to_json
end

# PUT /api/v1/votes/comments/:comment_id/users/:user_id
# create or update the vote on the comment

put '/api/v1/votes/comments/:comment_id/users/:user_id' do |comment_id, user_id|
  comment = Comment.find(comment_id)
  user = User.find_or_create_by(external_id: user_id)
  user.vote(comment, params["value"].intern)
  Comment.find(comment_id).to_hash.to_json
end

# DELETE /api/v1/votes/comments/:comment_id/users/:user_id
# unvote on the comment

delete '/api/v1/votes/comments/:comment_id/users/:user_id' do |comment_id, user_id|
  comment = Comment.find(comment_id)
  user = User.find_or_create_by(external_id: user_id)
  user.unvote(comment)
  Comment.find(comment_id).to_hash.to_json
end

# PUT /api/v1/votes/comment_threads/:comment_thread_id/users/:user_id
# create or update the vote on the comment thread

put '/api/v1/votes/comment_threads/:comment_thread_id/users/:user_id' do |comment_thread_id, user_id|
  comment_thread = CommentThread.find(comment_thread_id)
  user = User.find_or_create_by(external_id: user_id)
  user.vote(comment_thread, params["value"].intern)
  CommentThread.find(comment_thread_id).to_hash.to_json
end

# DELETE /api/v1/votes/comment_threads/:comment_thread_id/users/:user_id
# unvote on the comment thread

delete '/api/v1/votes/comment_threads/:comment_thread_id/users/:user_id' do |comment_thread_id, user_id|
  comment_thread = CommentThread.find(comment_thread_id)
  user = User.find_or_create_by(external_id: user_id)
  user.unvote(comment_thread)
  CommentThread.find(comment_thread_id).to_hash.to_json
end

# GET /api/v1/users/:user_id/feeds
# get all subscribed feeds for the user

get '/api/v1/users/:user_id/feeds' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  user.feeds.map(&:to_hash).to_json
end

# POST /api/v1/users/:user_id/follow
# follow user

post '/api/v1/users/:user_id/follow' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  followed_user = User.find_or_create_by(external_id: params[:user_id])
  user.follow(followed_user)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/unfollow
# unfollow user

post '/api/v1/users/:user_id/unfollow' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  followed_user = User.find_or_create_by(external_id: params[:user_id])
  user.unfollow(followed_user)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/watch/commentable
# watch a commentable

post '/api/v1/users/:user_id/watch/commentable' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  commentable = Commentable.find_or_create_by(commentable_type: params[:commentable_type],
                                              commentable_id: parasm[:commentable_id])
  user.watch_commentable(commentable)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/unwatch/commentable
# unwatch a commentable

post '/api/v1/users/:user_id/unwatch/commentable' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  commentable = Commentable.find_or_create_by(commentable_type: params[:commentable_type],
                                              commentable_id: parasm[:commentable_id])
  user.unwatch_commentable(commentable)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/watch/comment_thread
# watch a comment thread

post '/api/v1/users/:user_id/watch/comment_thread' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  comment_thread = CommentThread.find(params[:comment_thread_id])
  user.watch_comment_thread(comment_thread)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/unwatch/comment_thread
# unwatch a comment thread

post '/api/v1/users/:user_id/unwatch/comment_thread' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  comment_thread = CommentThread.find(params[:comment_thread_id])
  user.unwatch_comment_thread(comment_thread)
  user.to_hash.to_json
end

if env.to_s == "development"
  get '/api/v1/clean' do
    Comment.delete_all
    CommentThread.delete_all
    Commentable.delete_all
    User.delete_all
    Feed.delete_all
    {}.to_json
  end
end
