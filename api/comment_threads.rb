
get "#{APIPREFIX}/threads" do # retrieve threads by course
  # "sort_key" parameter will change order of threads returned and so may not always return in order
  # of most comments to least number of comments.

  # Note also that sorting sorts the pinned threads first and is not handled by elasticsearch but rather as a
  # part of the mongo query done once the thread IDs have been retrieved from ES.
  threads = CommentThread.where({"course_id" => params["course_id"]})
  if params[:commentable_ids]
    threads = threads.in({"commentable_id" => params[:commentable_ids].split(",")})
  end

  handle_threads_query(
    threads,
    params["user_id"],
    params["course_id"],
    get_group_ids_from_params(params),
    params["author_id"],
    params["thread_type"],
    value_to_boolean(params["flagged"]),
    value_to_boolean(params["unread"]),
    value_to_boolean(params["unanswered"]),
    value_to_boolean(params["count_flagged"]),
    params["sort_key"],
    params["page"],
    params["per_page"]
  ).to_json
end

get "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  begin
    thread = CommentThread.find(thread_id)
  rescue Mongoid::Errors::DocumentNotFound
    error 404, [t(:requested_object_not_found)].to_json
  end

  # user is required to return user-specific fields, such as "read" (even if bool_mark_as_read is False)
  if params["user_id"]
    user = User.only([:id, :username, :read_states]).find_by(external_id: params["user_id"])
  end
  if user and bool_mark_as_read
    user.mark_as_read(thread)
  end

  presenter = ThreadPresenter.factory(thread, user || nil)
  if params.has_key?("resp_skip")
    unless (resp_skip = Integer(params["resp_skip"]) rescue nil) && resp_skip >= 0
      error 400, [t(:param_must_be_a_non_negative_number, :param => 'resp_skip')].to_json
    end
  else
    resp_skip = 0
  end
  if params["resp_limit"]
    unless (resp_limit = Integer(params["resp_limit"]) rescue nil) && resp_limit >= 0
      error 400, [t(:param_must_be_a_number_greater_than_zero, :param => 'resp_limit')].to_json
    end
  else
    resp_limit = CommentService.config["thread_response_default_size"]
  end
  size_limit = CommentService.config["thread_response_size_limit"]
  unless (resp_limit <= size_limit)
    error 400, [t(:param_exceeds_limit, :param => resp_limit, :limit => size_limit)].to_json
  end
  presenter.to_hash(bool_with_responses, resp_skip, resp_limit, bool_recursive).to_json
end

put "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  filter_blocked_content params["body"]
  updated_content = params.slice(*%w[title body pinned closed commentable_id group_id thread_type close_reason_code])
  # If a close reason code is provided, save it. If a thread is being reopened, clear the closed_by flag
  if updated_content.has_key? CLOSED and updated_content.has_key? CLOSE_REASON_CODE
    if updated_content[CLOSED]
      updated_content["closed_by"] = user
    else
      updated_content["closed_by"] = nil
    end
  end
  if updated_content.has_key? BODY and updated_content[BODY] != thread.body
    edit_reason_code = params.fetch("edit_reason_code", nil)
    thread.edit_history.build(
      original_body: thread.body,
      author: user,
      reason_code: edit_reason_code,
      editor_username: user.username,
    )
    thread.save
  end
  thread.update_attributes(updated_content)

  if thread.errors.any?
    error 400, thread.errors.full_messages.to_json
  else
    presenter = ThreadPresenter.factory(thread, nil)
    presenter.to_hash.to_json
  end
end

post "#{APIPREFIX}/threads/:thread_id/comments" do |thread_id|
  filter_blocked_content params["body"]
  comment = Comment.new(params.slice(*%w[body course_id]))
  comment.anonymous = bool_anonymous || false
  comment.anonymous_to_peers = bool_anonymous_to_peers || false
  comment.author = user
  comment.comment_thread = thread
  comment.child_count = 0
  comment.save
  if comment.errors.any?
    error 400, comment.errors.full_messages.to_json
  else
    user.subscribe(thread) if bool_auto_subscribe
    # Mark thread as read for owner user on comment creation
    user.mark_as_read(thread)
    comment.to_hash.to_json
  end
end

delete "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  thread.destroy
  thread.to_hash.to_json
end
