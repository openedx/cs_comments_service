get "#{APIPREFIX}/comments/:comment_id" do |comment_id|
  comment.to_hash(recursive: bool_recursive).to_json
end

put "#{APIPREFIX}/comments/:comment_id" do |comment_id|
  filter_blocked_content params["body"]
  updated_content = params.slice(*%w[body endorsed])
  if params.has_key?("endorsed")
    new_endorsed_val = Boolean.mongoize(params["endorsed"])
    if new_endorsed_val != comment.endorsed
      if params["endorsement_user_id"].nil?
        endorsement = nil
      else
        endorsement = {:user_id => params["endorsement_user_id"], :time => DateTime.now}
      end
      updated_content["endorsement"] = new_endorsed_val ? endorsement : nil
    end
  end
  comment.update_attributes(updated_content)
  if comment.errors.any?
    error 400, comment.errors.full_messages.to_json
  else
    comment.to_hash.to_json
  end
end

post "#{APIPREFIX}/comments/:comment_id" do |comment_id|
  filter_blocked_content params["body"]
  sub_comment = comment.children.new(params.slice(*%w[body course_id]))
  sub_comment.anonymous = bool_anonymous || false
  sub_comment.anonymous_to_peers = bool_anonymous_to_peers || false
  sub_comment.author = user
  sub_comment.comment_thread = comment.comment_thread
  sub_comment.save
  if sub_comment.errors.any?
    error 400, sub_comment.errors.full_messages.to_json
  else
    user.subscribe(comment.comment_thread) if bool_auto_subscribe
    sub_comment.to_hash.to_json
  end
end

delete "#{APIPREFIX}/comments/:comment_id" do |comment_id|
  comment.destroy
  comment.to_hash.to_json
end
