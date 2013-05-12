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

get "#{APIPREFIX}/users/:user_id/active_threads" do |user_id|
  return {}.to_json if not params["course_id"]

  get_thread_id = lambda {|c| c._type == "Comment" ? c.comment_thread_id : c.id}
  get_thread = lambda {|thread_id| CommentThread.find(thread_id)}

  page = (params["page"] || DEFAULT_PAGE).to_i
  per_page = (params["per_page"] || DEFAULT_PER_PAGE).to_i

  active_contents = Content.where(author_id: user_id, anonymous: false, anonymous_to_peers: false, course_id: params["course_id"])
                           .order_by(updated_at: :desc)

  num_pages = [1, (active_contents.count / per_page.to_f).ceil].max
  page = [num_pages, [1, page].max].min

  paged_active_contents = active_contents.page(page).per(per_page)
  paged_thread_ids = paged_active_contents.map(&get_thread_id).uniq
  paged_active_threads = CommentThread.find(paged_thread_ids)

  # Fetch all the usernames in bulk to save on queries. Since we're using the
  # identity map, the users won't need to be fetched again later.
  User.only(:username).find(paged_active_threads.map{|x| x.author_id})

  collection = paged_active_threads.map{|t| t.to_hash recursive: true}
  collection = author_contents_only(collection, user_id)

  {
    collection: collection,
    num_pages: num_pages,
    page: page,
  }.to_json
  
end

put "#{APIPREFIX}/users/:user_id" do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  user.update_attributes(params.slice(*%w[username email default_sort_key]))
  if user.errors.any?
    error 400, user.errors.full_messages.to_json
  else
    user.to_hash.to_json
  end
end
