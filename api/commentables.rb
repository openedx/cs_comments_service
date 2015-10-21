delete "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  commentable.comment_threads.destroy_all
  {}.to_json
end

get "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  threads = Content.where({"_type" => "CommentThread", "commentable_id" => commentable_id})
  if params["course_id"]
    threads = threads.where({"course_id" => params["course_id"]})
  end

  handle_threads_query(
    threads,
    params["user_id"],
    params["course_id"],
    get_group_ids_from_params(params),
    value_to_boolean(params["flagged"]),
    value_to_boolean(params["unread"]),
    value_to_boolean(params["unanswered"]),
    params["sort_key"],
    params["sort_order"],
    params["page"],
    params["per_page"],
    params["context"] ? params["context"] : :course
  ).to_json
end

post "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  filter_blocked_content params["body"]
  thread = CommentThread.new(params.slice(*%w[title body course_id ]).merge(commentable_id: commentable_id))
  thread.thread_type = params["thread_type"] || :discussion
  thread.anonymous = bool_anonymous || false
  thread.anonymous_to_peers = bool_anonymous_to_peers || false
  
  if params["group_id"]
    thread.group_id = params["group_id"]
  end

  if params["context"]
    thread.context = params["context"]
  end
  
  thread.author = user
  thread.save
  if thread.errors.any?
    error 400, thread.errors.full_messages.to_json
  else
    user.subscribe(thread) if bool_auto_subscribe
    presenter = ThreadPresenter.factory(thread, nil)
    thread = presenter.to_hash
    thread["resp_total"] = 0
    thread.to_json
  end
end
