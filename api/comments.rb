get "#{APIPREFIX}/comments" do
  # The `user_id` is passed via a query string, as opposed to making
  # comments a sub-resource of a user-specific endpoint, so that this
  # endpoint is decoupled from the specific use case of getting comments
  # from an user, and can be extended, in the future, with alternative
  # methods of filtering.

  # handle filters
  error 400, "user_id is required" unless params['user_id']
  query = Comment.where(
    author_id: params['user_id'],
    anonymous: false,
    anonymous_to_peers: false,
  )

  error 400, "course_id is required" unless params['course_id']
  query = query.where(course_id: params['course_id'])

  if value_to_boolean(params["flagged"])
    query = query.where(:abuse_flaggers.nin => [nil, []])
  end

  if params["order_by"] and params["order_by"] == "flagged"
      query = query.order(:abuse_flaggers.desc)
  end

  query = query.order(:created_at.desc)

  # handle pagination
  page = (params['page'] || DEFAULT_PAGE).to_i
  per_page = (params['per_page'] || DEFAULT_PER_PAGE).to_i
  paginated_collection = query.paginate(:page => page, :per_page => per_page)
  comment_count = paginated_collection.total_entries

  {
    collection: paginated_collection.map { |c| c.to_hash },
    comment_count: comment_count,
    num_pages: [1, (comment_count / per_page.to_f).ceil].max,
    page: page,
  }.to_json
end

get "#{APIPREFIX}/comments/:comment_id" do |comment_id|
  @comment = comment
  comment_hash = @comment.to_hash(recursive: bool_recursive)
  verify_or_fix_cached_comment_count(@comment, comment_hash)
  comment_hash.to_json
end

put "#{APIPREFIX}/comments/:comment_id" do |comment_id|
  filter_blocked_content params["body"]
  updated_content = params.slice(*%w[body endorsed])
  if params.has_key?("endorsed")
    new_endorsed_val = Mongoid::Boolean.mongoize(params["endorsed"])
    if new_endorsed_val != comment.endorsed
      if params["endorsement_user_id"].nil?
        endorsement = nil
      else
        endorsement = {:user_id => params["endorsement_user_id"], :time => DateTime.now}
      end
      updated_content["endorsement"] = new_endorsed_val ? endorsement : nil
    end
  end
  if params[:editing_user_id]
    if updated_content.has_key? BODY and updated_content[BODY] != comment.body
      edit_reason_code = params.fetch("edit_reason_code", nil)
      editor = User.find_by(external_id: params[:editing_user_id])
      comment.edit_history.build(
        original_body: comment.body,
        author: editor,
        reason_code: edit_reason_code,
        editor_username: editor.username,
      )
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
  sub_comment.child_count = 0
  sub_comment.save
  if sub_comment.errors.any?
    error 400, sub_comment.errors.full_messages.to_json
  else
    comment.update_cached_child_count
    if comment.errors.any?
      error 400, comment.errors.full_messages.to_json
    else
      user.subscribe(comment.comment_thread) if bool_auto_subscribe
      # Mark thread as read for owner user on response creation
      user.mark_as_read(comment.comment_thread)
      sub_comment.to_hash.to_json
    end
  end
end

delete "#{APIPREFIX}/comments/:comment_id" do |comment_id|
  parent_id = comment.parent_id
  comment_as_json = comment.to_hash.to_json
  comment.destroy
  unless parent_id.nil?
    begin
      parent_comment = Comment.find(parent_id)
      parent_comment.update_cached_child_count
    rescue Mongoid::Errors::DocumentNotFound
      pass
    end
  end
  comment_as_json
end
