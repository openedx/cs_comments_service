require 'rubygems'
require 'yajl'
require 'active_record'
require 'sinatra'

require_relative 'models/comment'
require_relative 'models/comment_thread'
require_relative 'models/vote'

env_index = ARGV.index("-e")
env_arg = ARGV[env_index + 1] if env_index
env = env_arg || ENV["SINATRA_ENV"] || "development"
databases = YAML.load_file("config/database.yml")
ActiveRecord::Base.establish_connection(databases[env])

# retrive all comments of a commentable object
get '/api/v1/commentables/:commentable_type/:commentable_id/comments' do |commentable_type, commentable_id|
  comment_thread = CommentThread.find_or_create_by_commentable_type_and_commentable_id(commentable_type, commentable_id)
  comment_thread.json_comments
end

# create a new top-level comment
post '/api/v1/commentables/:commentable_type/:commentable_id/comments' do |commentable_type, commentable_id|
  comment_thread = CommentThread.find_or_create_by_commentable_type_and_commentable_id(commentable_type, commentable_id)
  comment_params = params.select {|key, value| %w{body title user_id course_id}.include? key}
  comment_params.merge :comment_thread_id => comment_thread.id
  comment = comment_thread.root_comments.create(comment_params)
  if comment.valid?
    comment.to_json
  else
    error 400, comment.errors.to_json
  end
end

# delete a commentable object and its associated comments
delete '/api/v1/commentables/:commentable_type/:commentable_id' do |commentable_type, commentable_id|
  comment_thread = CommentThread.find_by_commentable_type_and_commentable_id(commentable_type, commentable_id)
  if comment_thread.nil?
    error 400, {:error => "commentable object does not exist"}.to_json
  else
    comment_thread.destroy
    comment_thread.to_json
  end
end

# create a new subcomment (reply to comment) only if the comment is NOT a super comment
post '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find_by_id(comment_id)
  if comment.nil? or comment.is_root?
    error 400, {:error => "invalid comment id"}.to_json
  else
    comment_params = params.select {|key, value| %w{body title user_id course_id}.include? key}
    comment_params.merge :comment_thread_id => comment.root.comment_thread.id
    sub_comment = comment.children.create(comment_params)
    if comment.valid?
      comment.to_json
    else
      error 400, comment.errors.to_json
    end
  end
end

# delete the comment and the associated sub comments only if the comment is NOT the super comment
delete '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find_by_id(comment_id)
  if comment.nil? or comment.is_root?
    error 400, {:error => "invalid comment id"}.to_json
  else
    comment.destroy
    comment.to_json
  end
end

# update the body / title (or both) of a comment provided the comment is NOT the super comment
put '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find_by_id(comment_id)
  if comment.nil? or comment.is_root?
    error 400, {:error => "invalid comment id"}.to_json
  else
    comment_params = params.select {|key, value| %w{body title}.include? key}
    if comment.update_attributes(comment_params)
      comment.to_json
    else
      error 400, comment.errors.to_json
    end
  end
end

# create or update the vote on the comment by the user
put '/api/v1/votes/comments/:comment_id/users/:user_id' do |comment_id, user_id|
  if not %w{up down}.include? params["value"]
    error 400, {:error => "value must be up or down"}.to_json
  else
    comment = Comment.find_by_id(comment_id)
    if comment.nil?
      error 400, {:error => "invalid comment id"}.to_json
    else
      vote = Vote.create_or_update :user_id => user_id, :comment_id => comment_id, :value => params["value"]
      if vote
        vote.to_json
      else
        error 400, vote.errors.to_json
      end
    end
  end
end

# undo the vote on the comment by the user
delete '/api/v1/votes/comments/:comment_id/users/:user_id' do |comment_id, user_id|
  vote = Vote.find_by_comment_id_and_user_id(comment_id, user_id)
  if vote.nil?
    error 400, {:error => "vote does not exist"}.to_json
  else
    vote.destroy
    vote.to_json
  end
end

if env.to_s == "development"
  get '/api/v1/clean' do
    Comment.delete_all
    CommentThread.delete_all
    Vote.delete_all
    {}.to_json
  end
end
