require_relative '../mongoutil'

post "#{APIPREFIX}/users" do
  user = User.new(external_id: params["id"])
  user.username = params["username"]
  user.save
  if user.errors.any?
    error 400, user.errors.full_messages.to_json
  else
    user.to_hash.to_json
  end
end

get "#{APIPREFIX}/users/:course_id/stats" do |course_id|
  user_data = {}
  data = Content.collection.aggregate(
    [
      # Match all content in the course
      { "$match" => { :course_id => course_id } },
      # Keep a count of flags for each entry
      {
        "$set" => {
          # Just using $ne with null will return true if the field is absent
          # So we first fall all absent fields to null, then check if it's null,
          # that way we match for the absence of the field or value = null
          :is_reply => { "$ne" => [{ "$ifNull" => ["$parent_id", nil] }, nil] }
        }
      },
      {
        "$group" => {
          # Here we're grouping items by the type (comment or thread), and the user, and whether the comment is a reply.
          # For threads is_reply will always be false.
          :_id => { :type => "$_type", :author_id => "$author_id", :is_reply => "$is_reply" },
          # This will just count each group, so we get a breakdown of how many comments and threads a user has created.
          :count => { "$sum" => 1 },
          # These two will sum up the active and inactive reports in each category
          # i.e. reported threads, reported comments, reported replies
          # The way this works is (starting from inside out), we take the size of the abuse_flaggers list, we compare
          # it to 0 using $cmp. If it's greater than zero then $cmp results in 1 otherwise 0.
          # So we're summing up 1 for each abuse_flagger array that has entries, and 0 for the rest. This gives us a
          # count of
          :active_flags => { "$sum" => { "$cmp" => [{ "$size" => "$abuse_flaggers" }, 0] } },
          :inactive_flags => { "$sum" => { "$cmp" => [{ "$size" => "$historical_abuse_flaggers" }, 0] } },
        }
      }
    ])
  data.each do |counts|
    type, author_id, is_reply = counts[:_id].values_at "type", "author_id", "is_reply"
    count, active_flags, inactive_flags = counts.values_at "count", "active_flags", "inactive_flags"
    unless user_data.has_key? author_id
      user_data[author_id] = {
        :author_id => author_id,
        :active_flags => 0,
        :inactive_flags => 0,
        :threads => 0,
        :responses => 0,
        :replies => 0
      }
    end
    if type == "Comment" and is_reply
      user_data[author_id][:replies] = count
    elsif type == "Comment" and not is_reply
      user_data[author_id][:responses] = count
    else
      user_data[author_id][:threads] = count
    end
    user_data[author_id][:active_flags] += active_flags
    user_data[author_id][:inactive_flags] += inactive_flags
  end
  user_data.to_json
end

get "#{APIPREFIX}/users/:user_id" do |user_id|
  begin
    # Get any group_ids that may have been specified (will be an empty list if none specified).
    group_ids = get_group_ids_from_params(params)
    user.to_hash(complete: bool_complete, course_id: params["course_id"], group_ids: group_ids).to_json
  rescue Mongoid::Errors::DocumentNotFound
    error 404
  end
end

get "#{APIPREFIX}/users/:user_id/active_threads" do |user_id|
  return {}.to_json if not params["course_id"]

  page = (params["page"] || DEFAULT_PAGE).to_i
  per_page = (params["per_page"] || DEFAULT_PER_PAGE).to_i
  per_page = DEFAULT_PER_PAGE if per_page <= 0

  active_contents = Content.where(author_id: user_id, anonymous: false, anonymous_to_peers: false, course_id: params["course_id"])
                           .order_by(updated_at: :desc)

  # Get threads ordered by most recent activity, taking advantage of the fact
  # that active_contents is already sorted that way
  active_thread_ids = active_contents.inject([]) do |thread_ids, content|
    thread_id = content._type == "Comment" ? content.comment_thread_id : content.id
    thread_ids << thread_id if not thread_ids.include?(thread_id)
    thread_ids
  end

  threads = CommentThread.course_context.in({"_id" => active_thread_ids})

  group_ids = get_group_ids_from_params(params)
  if not group_ids.empty?
    threads = get_group_id_criteria(threads, group_ids)
  end

  num_pages = [1, (threads.count / per_page.to_f).ceil].max
  page = [num_pages, [1, page].max].min

  sorted_threads = threads.sort_by {|t| active_thread_ids.index(t.id)}
  paged_threads = sorted_threads[(page - 1) * per_page, per_page]

  presenter = ThreadListPresenter.new(paged_threads, user, params[:course_id])
  collection = presenter.to_hash

  json_output = nil
  json_output = {
  collection: collection,
  num_pages: num_pages,
  page: page,
  }.to_json
  json_output

end

put "#{APIPREFIX}/users/:user_id" do |user_id|
  reconnect_mongo_primary
  user = User.find_or_create_by(external_id: user_id)
  user.update_attributes(params.slice(*%w[username default_sort_key]))
  if user.errors.any?
    error 400, user.errors.full_messages.to_json
  else
    user.to_hash.to_json
  end
end

post "#{APIPREFIX}/users/:user_id/read" do |user_id|
  user.mark_as_read(source)
  user.reload.to_hash.to_json
end

post "#{APIPREFIX}/users/:user_id/retire" do |user_id|
  if not params["retired_username"]
    error 500, {message: "Missing retired_username param."}.to_json
  end
  begin
    user = User.find_by(external_id: user_id)
  rescue Mongoid::Errors::DocumentNotFound
    error 404, {message: "User not found."}.to_json
  end
  user.update_attribute(:email, "")
  user.update_attribute(:notification_ids, [])
  user.update_attribute(:read_states, [])
  user.unsubscribe_all
  user.retire_all_content(params["retired_username"])
  user.update_attribute(:username, params["retired_username"])
  user.save
end

post "#{APIPREFIX}/users/:user_id/replace_username" do |user_id|
  if not params["new_username"]
    error 500, {message: "Missing new_username param. "}.to_json
  end
  begin
    user = User.find_by(external_id: user_id)
  rescue Mongoid::Errors::DocumentNotFound
    error 404, {message: "User not found."}.to_json
  end
  user.update_attribute(:username, params["new_username"])
  user.replace_username_in_all_content(params["new_username"])
  user.save
end
