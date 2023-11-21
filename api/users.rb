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
  with_timestamps = value_to_boolean(params["with_timestamps"])

  usernames = params.fetch("usernames", '').split(',')

  # There are two sorts available, activity sort and flagged sort.
  sort_by = params["sort_key"]
  if sort_by == "flagged"
    # If sorting by flags we sort by active flags and then inactive flags
    sort_criterion = {
      "course_stats.active_flags" => -1,
      "course_stats.inactive_flags" => -1,
      "username" => -1,
    }
  elsif sort_by == "recency"
    sort_criterion = {
      "course_stats.last_activity_at" => -1,
      "username" => -1,
    }
  else
    # If sorting by activity (default) sort by thread count, then responses, then replies.
    sort_criterion = {
      "course_stats.threads" => -1,
      "course_stats.responses" => -1,
      "course_stats.replies" => -1,
      "username" => -1,
    }
  end

  exclude_from_stats = ["_id", "course_id"]
  unless with_timestamps
    exclude_from_stats.append "last_activity_at"
  end

  if usernames.empty?
    paginated_stats = User.collection
                          .aggregate([
                                       # Match only users that have stats for this course
                                       { '$match' => { "course_stats.course_id" => course_id } },
                                       # Get only the username and course stats since that's all we need
                                       { '$project' => { 'username' => 1, 'course_stats' => 1 } },
                                       # Get rid of other course entries by expanding the course stats
                                       # and filtering out other courses
                                       { '$unwind' => '$course_stats' },
                                       { '$match' => { "course_stats.course_id" => course_id } },
                                       { '$sort' => sort_criterion },
                                       # Split the query and get a total count in one facet and
                                       # perform the pagination iin the other
                                       { '$facet' => {
                                         'pagination' => [{"$count" => "total_count"}],
                                         'data' => [
                                           { '$skip' => (page - 1) * per_page },
                                           { '$limit' => per_page },
                                         ]
                                       }}
                                     ]).to_a[0]
    data = []
    num_pages = 0
    page = 0
    total_count = 0
    if not paginated_stats["pagination"].empty?
      total_count = paginated_stats["pagination"][0]["total_count"]
      num_pages = [1, (total_count / per_page.to_f).ceil].max
      data = paginated_stats["data"].map do |user_stats|
        {
          :username => user_stats["username"]
        }.merge(user_stats["course_stats"].except(*exclude_from_stats))
      end
    end
  else
    # If a list of usernames is provided, then sort by the order in which those names appear
    stats_query = User.where("course_stats.course_id" => course_id)
                      .in(username: usernames)
                      .only(:username, :'course_stats.$') # Only return the username and the course stats document matched above.
    paginated_stats = stats_query.sort_by { |u| usernames.index(u.username) }
    # Search results are not paginated
    total_count = paginated_stats.length
    num_pages = 1
    data = paginated_stats.to_a.map do |user_stats|
      {
        :username => user_stats["username"]
      }.merge(user_stats["course_stats"].first.except(*exclude_from_stats))
    end
  end

  {
    user_stats: data,
    num_pages: num_pages,
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
  return {}.to_json unless params["course_id"]

  page = (params["page"] || DEFAULT_PAGE).to_i
  per_page = (params["per_page"] || DEFAULT_PER_PAGE).to_i
  per_page = DEFAULT_PER_PAGE if per_page <= 0
  sort_key = params["sort_key"] || 'user_activity'
  raw_query = (sort_key == 'user_activity')

  count_flagged = value_to_boolean(params["count_flagged"])
  filter_flagged = value_to_boolean(params["flagged"])

  active_contents = Content.where(
    author_id: user_id,
    anonymous: false,
    anonymous_to_peers: false,
    course_id: params["course_id"]
  )

  if filter_flagged
    active_contents = active_contents.where(
        :abuse_flaggers.ne => [],
        :abuse_flaggers.exists => true
    )
  end

  active_contents = active_contents.order_by(updated_at: :desc)

  # Get threads ordered by most recent activity, taking advantage of the fact
  # that active_contents is already sorted that way
  active_thread_ids = active_contents.inject([]) do |thread_ids, content|
    thread_id = content._type == "Comment" ? content.comment_thread_id : content.id
    thread_ids << thread_id unless thread_ids.include?(thread_id)
    thread_ids
  end

  threads = CommentThread.in({ "_id" => active_thread_ids })

  threads_data = handle_threads_query(
    threads,
    user_id,
    params["course_id"],
    get_group_ids_from_params(params),
    params["author_id"],
    params["thread_type"],
    false, # Filter flagged is already applied
    value_to_boolean(params["unread"]),
    value_to_boolean(params["unanswered"]),
    value_to_boolean(params["unresponded"]),
    count_flagged,
    sort_key,
    page,
    per_page,
    raw_query: raw_query
  )

  if raw_query
    num_pages = [1, (threads_data.count / per_page.to_f).ceil].max
    page = [num_pages, [1, page].max].min

    sorted_threads = threads_data.sort_by { |t| active_thread_ids.index(t.id) }
    paged_threads = sorted_threads[(page - 1) * per_page, per_page]
    presenter = ThreadListPresenter.new(paged_threads, user, params[:course_id], count_flagged)
    {
      collection: presenter.to_hash,
      num_pages: num_pages,
      page: page,
    }.to_json
  else
    threads_data.to_json
  end

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
