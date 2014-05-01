require 'new_relic/agent/method_tracer'

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

get "#{APIPREFIX}/users/:user_id" do |user_id|
  begin
    user.to_hash(complete: bool_complete, course_id: params["course_id"]).to_json
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

  num_pages = [1, (active_thread_ids.count / per_page.to_f).ceil].max
  page = [num_pages, [1, page].max].min

  paged_thread_ids = active_thread_ids[(page - 1) * per_page, per_page]

  # Find all the threads by id, and then put them in the order found earlier.
  # Necessary because CommentThread.find does return results in the same
  # order as the provided ids.
  paged_active_threads = CommentThread.find(paged_thread_ids).sort_by do |t| 
    paged_thread_ids.index(t.id)
  end

  presenter = ThreadListPresenter.new(paged_active_threads.to_a, user, params[:course_id])
  collection = presenter.to_hash

  json_output = nil
  self.class.trace_execution_scoped(['Custom/get_user_active_threads/json_serialize']) do
    json_output = {
      collection: collection,
      num_pages: num_pages,
      page: page,
    }.to_json
  end
  json_output

end

put "#{APIPREFIX}/users/:user_id" do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  user.update_attributes(params.slice(*%w[username default_sort_key]))
  if user.errors.any?
    error 400, user.errors.full_messages.to_json
  else
    user.to_hash.to_json
  end
end
