get "#{APIPREFIX}/threads" do # retrieve threads by course
  
  threads = Content.where({"_type" => "CommentThread", "course_id" => params["course_id"]})
  if params[:commentable_ids]
    threads = threads.in({"commentable_id" => params[:commentable_ids].split(",")})
  end

  handle_threads_query(
    threads,
    params["user_id"],
    params["course_id"],
    params["group_id"],
    value_to_boolean(params["flagged"]),
    value_to_boolean(params["unread"]),
    value_to_boolean(params["unanswered"]),
    params["sort_key"],
    params["sort_order"],
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

  if params["user_id"] and bool_mark_as_read
    user = User.only([:id, :username, :read_states]).find_by(external_id: params["user_id"])
    user.mark_as_read(thread) if user
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
    resp_limit = nil
  end
  presenter.to_hash(true, resp_skip, resp_limit).to_json
end

put "#{APIPREFIX}/threads/:thread_id" do |thread_id|
  filter_blocked_content params["body"]
  thread.update_attributes(params.slice(*%w[title body closed commentable_id group_id]))

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

get "#{APIPREFIX}/courses/*/stats"  do |course_id| # retrieve stats by course
  begin
    threads = Content.where(_type: "CommentThread", course_id: course_id)
    active_threads = threads.where(:last_activity_at.gte => 1.day.ago)
    course_stats = {
      "num_threads" => threads.count,
      "num_active_threads" => active_threads.count
    }
    course_stats.to_json
  end
end
