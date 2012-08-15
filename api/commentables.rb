delete "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  commentable.comment_threads.destroy_all
  {}.to_json
end

get "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|

  sort_key_mapper = {
    "date" => :created_at,
    "activity" => :last_activity_at,
    "votes" => :"votes.point",
    "comments" => :comment_count,
  }

  sort_order_mapper = {
    "desc" => :desc,
    "asc" => :asc,
  }
  
  sort_key = sort_key_mapper[params["sort_key"]]
  sort_order = sort_order_mapper[params["sort_order"]]
  sort_keyword_valid = (!params["sort_key"] && !params["sort_order"] || sort_key && sort_order)
  if not sort_keyword_valid
    {}.to_json
  else
    page = (params["page"] || DEFAULT_PAGE).to_i
    per_page = (params["per_page"] || DEFAULT_PER_PAGE).to_i
    comment_threads = commentable.comment_threads
    comment_threads = comment_threads.order_by("#{sort_key} #{sort_order}") if sort_key && sort_order
    num_pages = [1, (comment_threads.count / per_page.to_f).ceil].max
    page = [num_pages, [1, page].max].min
    paged_comment_threads = comment_threads.page(page).per(per_page)
    {
      collection: paged_comment_threads.map{|t| t.to_hash(recursive: bool_recursive)},
      num_pages: num_pages,
      page: page,
    }.to_json
  end
end

post "#{APIPREFIX}/:commentable_id/threads" do |commentable_id|
  thread = CommentThread.new(params.slice(*%w[title body course_id]).merge(commentable_id: commentable_id))
  thread.anonymous = bool_anonymous || false
  thread.tags = params["tags"] || ""
  thread.author = user
  thread.save
  if thread.errors.any?
    error 400, thread.errors.full_messages.to_json
  else
    user.subscribe(thread) if bool_auto_subscribe
    thread.to_hash.to_json
  end
end
