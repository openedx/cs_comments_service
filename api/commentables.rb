delete "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  commentable.comment_threads.destroy_all
  {}.to_json
end

get "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|

  handle_threads_query(commentable.comment_threads)
  
end

post "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  thread = CommentThread.new(params.slice(*%w[title body course_id]).merge(commentable_id: commentable_id))
  thread.anonymous = bool_anonymous || false
  thread.tags = params["tags"] || ""
  thread.author = user
  thread.save
  if thread.errors.any?
    error 400, thread.errors.full_messages.to_json
  else
    user.subscribe(thread) if bool_auto_subscribe
    thread.to_hash.to_json
  end
end
