get "#{APIPREFIX}/threads" do # retrieve threads by course
  handle_threads_query(CommentThread.where(course_id: params["course_id"]))
end

get "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  thread = CommentThread.find(thread_id)

  if params["user_id"] and bool_mark_as_read
    user = User.only([:id, :read_states]).find_or_create_by(external_id: params["user_id"])
    user.mark_as_read(thread)
  end

  thread.to_hash(recursive: bool_recursive, user_id: params["user_id"]).to_json
end

put "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  thread.update_attributes(params.slice(*%w[title body closed]))
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
