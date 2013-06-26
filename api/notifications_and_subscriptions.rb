get "#{APIPREFIX}/users/:user_id/notifications" do |user_id|
  user.notifications.map(&:to_hash).to_json
end

get "#{APIPREFIX}/users/:user_id/subscribed_threads" do |user_id|
  handle_threads_query(user.subscribed_threads)
end

post "#{APIPREFIX}/users/:user_id/subscriptions" do |user_id|
  user.subscribe(source).to_hash.to_json
end

delete "#{APIPREFIX}/users/:user_id/subscriptions" do |user_id|
  user.unsubscribe(source).to_hash.to_json
end


