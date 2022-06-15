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
  page = (params["page"] || DEFAULT_PAGE).to_i
  page = [1, page].max
  per_page = (params["per_page"] || DEFAULT_PER_PAGE).to_i
  per_page = DEFAULT_PER_PAGE if per_page <= 0

  usernames = params.fetch("usernames", '').split(',')

  # There are two sorts available, activity sort and flagged sort.
  sort_by = params["sort_key"]
  if sort_by == "flagged"
    # If sorting by flags we sort by active flags and then inactive flags
    sort_criterion = [
      ["course_stats.active_flags", :desc],
      ["course_stats.inactive_flags", :desc],
    ]
  else
    # If sorting by activity (default) sort by thread count, then responses, then replies.
    sort_criterion = [
      ["course_stats.threads", :desc],
      ["course_stats.responses", :desc],
      ["course_stats.replies", :desc],
    ]
  end

  stats_query = User
                  .where("course_stats.course_id" => course_id)
                  .only(:username, :'course_stats.$') # Only return the username and the course stats document matched above.
                  .order_by(sort_criterion)
  unless usernames.empty?
    stats_query = stats_query.in(username: usernames)
  end
  paginated_stats = stats_query.paginate(:page => page, :per_page => per_page)
  total_count = paginated_stats.total_entries

  data = paginated_stats.to_a.map do |user_stats|
    {
      :username => user_stats["username"]
    }.merge(user_stats["course_stats"].first.except("_id", "course_id"))
  end

  {
    user_stats: data,
    num_pages: [1, (total_count / per_page.to_f).ceil].max,
    page: page,
    count: total_count,
  }.to_json
end

post "#{APIPREFIX}/users/:course_id/update_stats" do |course_id|
  updated_users = update_all_users_in_course(course_id)
  { user_count: updated_users.length }.to_json
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
