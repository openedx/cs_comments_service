post "#{APIPREFIX}/users" do
  user = User.new(external_id: params["id"])
  user.username = params["username"]
  user.email = params["email"]
  user.save
  if user.errors.any?
    error 400, user.errors.full_messages.to_json
  else
    user.to_hash.to_json
  end
end

get "#{APIPREFIX}/users/:user_id" do |user_id|
  user.to_hash(complete: bool_complete, course_id: params["course_id"]).to_json
end

put "#{APIPREFIX}/users/:user_id" do |user_id|
  user = User.where(external_id: user_id).first
  if not user
    user = User.new(external_id: user_id)
  end
  user.update_attributes(params.slice(*%w[username email]))
  if user.errors.any?
    error 400, user.errors.full_messages.to_json
  else
    user.to_hash.to_json
  end
end
