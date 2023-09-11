get "#{APIPREFIX}/users/:user_id/notifications" do |user_id|
  user.notifications.map(&:to_hash).to_json
end

get "#{APIPREFIX}/users/:user_id/subscribed_threads" do |user_id|
  handle_threads_query(
    user.subscribed_threads.where({ "course_id" => params[:course_id] }),
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
    params["per_page"]
  ).to_json
end

post "#{APIPREFIX}/users/:user_id/subscriptions" do |user_id|
  user.subscribe(source).to_hash.to_json
end

delete "#{APIPREFIX}/users/:user_id/subscriptions" do |user_id|
  user.unsubscribe(source).to_hash.to_json
end

get "#{APIPREFIX}/threads/:thread_id/subscriptions" do |thread_id|
  page = (params['page'] || DEFAULT_PAGE).to_i
  per_page = (params['per_page'] || DEFAULT_PER_PAGE).to_i

  # Build a query hash based on the query parameters
  query = {}
  query[:source_id] = thread_id
  query[:source_type] = 'CommentThread'

  subscriptions = Subscription.where(query).paginate(:page => page, :per_page => per_page)
  subscriptions_count = subscriptions.total_entries

  content_type :json

  {
    collection: subscriptions.map(&:to_hash),
    num_pages: [1, (subscriptions_count / per_page.to_f).ceil].max,
    page: page,
    subscriptions_count: subscriptions_count
  }.to_json
end
