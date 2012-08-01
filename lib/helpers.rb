helpers do
  def commentable
    @commentable ||= Commentable.find(params[:commentable_id])
  end

  def user # TODO handle 404 if integrated user service
    raise ArgumentError, "User id is required" unless @user || params[:user_id]
    @user ||= User.find_or_create_by(external_id: params[:user_id])
  end

  def thread
    @thread ||= CommentThread.find(params[:thread_id])
  end

  def comment
    @comment ||= Comment.find(params[:comment_id])
  end

  def source
    @source ||= case params["source_type"]
    when "user"
      User.find_or_create_by(external_id: params["source_id"])
    when "thread"
      CommentThread.find(params["source_id"])
    when "other"
      Commentable.find(params["source_id"])
    else
      raise ArgumentError, "Source type must be 'user', 'thread' or 'other'"
    end
  end

  def vote_for(obj)
    raise ArgumentError, "User id is required" unless user
    raise ArgumentError, "Value is required" unless params["value"]
    raise ArgumentError, "Value is invalid" unless %w[up down].include? params["value"]
    user.vote(obj, params["value"].to_sym)
    obj.reload.to_hash.to_json
  end

  def undo_vote_for(obj)
    raise ArgumentError, "must provide user id" unless user
    user.unvote(obj)
    obj.reload.to_hash.to_json
  end

  def value_to_boolean(value)
    !!(value.to_s =~ /^true$/i)
  end

end
