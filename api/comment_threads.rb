get "#{APIPREFIX}/threads" do # retrieve threads by course
  #if a group id is sent, then process the set of threads with that group id or with no group id
  if params["group_id"]
    threads = CommentThread.any_of(
    {:course_id => params["course_id"],:group_id => params[:group_id]},
    {:course_id => params["course_id"],:group_id.exists => false},
    )
  else
    threads = CommentThread.where(course_id: params["course_id"])
    #else process them all
  end
  handle_threads_query(threads)
end

get "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  thread = CommentThread.find(thread_id)

  if params["user_id"] and bool_mark_as_read
    user = User.only([:id, :read_states]).find_by(external_id: params["user_id"])
    user.mark_as_read(thread) if user
  end

  thread.to_hash(recursive: bool_recursive, user_id: params["user_id"]).to_json
end

put "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  thread.update_attributes(params.slice(*%w[title body closed commentable_id group_id]))

  if params["tags"]
    thread.tags = params["tags"]
    thread.save
  end

  if thread.errors.any?
    error 400, thread.errors.full_messages.to_json
  else
    thread.to_hash.to_json
  end
end

post "#{APIPREFIX}/threads/:thread_id/comments" do |thread_id|
  comment = Comment.new(params.slice(*%w[body course_id]))
  comment.anonymous = bool_anonymous || false
  comment.anonymous_to_peers = bool_anonymous_to_peers || false
  comment.author = user
  comment.comment_thread = thread
  comment.save
  if comment.errors.any?
    error 400, comment.errors.full_messages.to_json
  else
    user.subscribe(thread) if bool_auto_subscribe
    comment.to_hash.to_json
  end
end

delete "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  thread.destroy
  thread.to_hash.to_json
end
