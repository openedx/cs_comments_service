get "#{APIPREFIX}/users/:user_id/notifications" do |user_id|
  user.notifications.map(&:to_hash).to_json
end

get "#{APIPREFIX}/users/:user_id/subscribed_threads" do |user_id|
  handle_threads_query(
    user.subscribed_threads.where({"course_id" => params[:course_id]}),
    params["user_id"],
    params["course_id"],
    get_group_ids_from_params(params),
    value_to_boolean(params["flagged"]),
    value_to_boolean(params["unread"]),
    value_to_boolean(params["unanswered"]),
    params["sort_key"],
    params["sort_order"],
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
