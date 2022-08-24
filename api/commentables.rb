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
    params["author_id"],
    params["thread_type"],
    value_to_boolean(params["flagged"]),
    value_to_boolean(params["unread"]),
    value_to_boolean(params["unanswered"]),
    value_to_boolean(params["unresponded"]),
    value_to_boolean(params["count_flagged"]),
    params["sort_key"],
    params["page"],
    params["per_page"],
    params["context"] ? params["context"] : :course
  ).to_json
end

get "#{APIPREFIX}/commentables/:course_id/counts" do |course_id|
  commentable_counts = {}
  Content.collection.aggregate(
    [
      # Match all threads in the course
      { "$match" => { :course_id => course_id, :_type => "CommentThread" } },
      # Group all the threads in the course by the type of thread and the topic of the thread
      # (represented by commentable_id) and keep a count of each
      {
        "$group" => {
          :_id => { :topic_id => "$commentable_id", :type => "$thread_type" },
          :count => { "$sum" => 1 },
        }
      }
    ]).each do |commentable|
    # The data returned by mongo is structured as rows mapping a topic id and thread type pair with a count
    # here we convert that to a map of topic id to thread counts of each type.
    topic_id = commentable[:_id][:topic_id]
    unless commentable_counts.has_key? topic_id
      commentable_counts[topic_id] = { :discussion => 0, :question => 0 }
    end
    commentable_counts[topic_id].merge! commentable[:_id][:type] => commentable["count"]
  end
  commentable_counts.to_json
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
    # Mark thread as read for owner user on creation
    user.mark_as_read(thread)
    user.subscribe(thread) if bool_auto_subscribe

    # Initialize ThreadPresenter; if non-null user is passed it also calculates
    # user specific data on initialization such as thread "read" status
    presenter = ThreadPresenter.factory(thread, user)
    thread = presenter.to_hash
    thread["resp_total"] = 0
    thread.to_json
  end
end
