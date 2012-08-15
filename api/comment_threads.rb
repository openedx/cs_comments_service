get "#{APIPREFIX}/threads" do # retrieve threads by course
  handle_threads_query(CommentThread.where(course_id: params["course_id"]))
end

get "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  CommentThread.find(thread_id).to_hash(recursive: bool_recursive).to_json
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
  comment = thread.comments.new(params.slice(*%w[body course_id]))
  comment.anonymous = bool_anonymous || false
  comment.author = user 
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
