delete "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  commentable.comment_threads.destroy_all
  {}.to_json
end

get "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  if params["group_id"]
    threads = CommentThread.any_of(
    {:commentable_id => commentable_id, :group_id => params[:group_id]}, 
    {:commentable_id => commentable_id, :group_id.exists => false}, 
    )
  else
    threads = commentable.comment_threads
  end
    handle_threads_query(threads)    
end

post "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  thread = CommentThread.new(params.slice(*%w[title body course_id ]).merge(commentable_id: commentable_id))
  thread.anonymous = bool_anonymous || false
  thread.anonymous_to_peers = bool_anonymous_to_peers || false
  thread.tags = params["tags"] || ""
  
  if params["group_id"]
    thread.group_id = params["group_id"]
  end
  
  thread.author = user
  thread.save
  if thread.errors.any?
    error 400, thread.errors.full_messages.to_json
  else
    user.subscribe(thread) if bool_auto_subscribe
    thread.to_hash.to_json
  end
end
