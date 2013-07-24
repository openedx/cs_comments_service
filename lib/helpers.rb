helpers do
  def commentable
    @commentable ||= Commentable.find(params[:commentable_id])
  end

  def user # TODO handle 404 if integrated user service
    raise ArgumentError, "User id is required" unless @user || params[:user_id]
    @user ||= User.find_by(external_id: params[:user_id])
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
      User.find_by(external_id: params["source_id"])
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

  def flag_as_abuse(obj)
    raise ArgumentError, "User id is required" unless user
    obj.abuse_flaggers << user.id unless obj.abuse_flaggers.include? user.id
    obj.save
    obj.reload.to_hash.to_json
  end
  
  def un_flag_as_abuse(obj)
    raise ArgumentError, "User id is required" unless user
    if params["all"]
      obj.historical_abuse_flaggers += obj.abuse_flaggers
      obj.historical_abuse_flaggers = obj.historical_abuse_flaggers.uniq
      obj.abuse_flaggers.clear
    else
      obj.abuse_flaggers.delete user.id
    end
    
    obj.save
    obj.reload.to_hash.to_json
  end

  def undo_vote_for(obj)
    raise ArgumentError, "must provide user id" unless user
    user.unvote(obj)
    obj.reload.to_hash.to_json
  end
  

  def pin(obj)
    raise ArgumentError, "User id is required" unless user
    obj.pinned = true
    obj.save
    obj.reload.to_hash.to_json
  end
  
  def unpin(obj)
    raise ArgumentError, "User id is required" unless user
    obj.pinned = nil
    obj.save
    obj.reload.to_hash.to_json
  end  
  
  
  
  def value_to_boolean(value)
    !!(value.to_s =~ /^true$/i)
  end

  def bool_recursive
    value_to_boolean params["recursive"]
  end

  def bool_mark_as_read
    value_to_boolean params["mark_as_read"]
  end

  def bool_complete
    value_to_boolean params["complete"]
  end

  def bool_auto_subscribe
    value_to_boolean params["auto_subscribe"]
  end

  def bool_anonymous
    value_to_boolean params["anonymous"]
  end

  def bool_anonymous_to_peers
    value_to_boolean params["anonymous_to_peers"]
  end

  def handle_paged_threads_query(paged_comment_threads)

  end

  def handle_threads_query(comment_threads)
    
      
    if params[:course_id]
      comment_threads = comment_threads.where(:course_id=>params[:course_id])
      
      if params[:flagged]
        #get flagged threads and threads containing flagged responses
        comment_ids = Comment.where(:course_id=>params[:course_id]).
          where(:abuse_flaggers.ne => [],:abuse_flaggers.exists => true).
          collect{|c| c.comment_thread_id}.uniq
          
        thread_ids = comment_threads.where(:abuse_flaggers.ne => [],:abuse_flaggers.exists => true).
          collect{|c| c.id}
          
        comment_ids += thread_ids
        
        comment_threads = comment_threads.where(:id.in => comment_ids)
        
      end
    end
    if CommentService.config[:cache_enabled]
      query_params = params.slice(*%w[course_id commentable_id sort_key sort_order page per_page user_id])
      memcached_key = "threads_query_#{query_params.hash}"
      cached_results = Sinatra::Application.cache.get(memcached_key)
      if cached_results
        return {
          collection: cached_results[:collection_ids].map{|id| CommentThread.find(id).to_hash(recursive: bool_recursive, user_id: params["user_id"])},
          num_pages: cached_results[:num_pages],
          page: cached_results[:page],
        }.to_json
      end
    end

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
      #KChugh turns out we don't need to go through all the extra work on the back end because the client is resorting anyway
      #KChugh boy was I wrong, we need to sort for pagination
      comment_threads = comment_threads.order_by("pinned DESC,#{sort_key} #{sort_order}") if sort_key && sort_order
      num_pages = [1, (comment_threads.count / per_page.to_f).ceil].max
      page = [num_pages, [1, page].max].min
      paged_comment_threads = comment_threads.page(page).per(per_page)
      if CommentService.config[:cache_enabled]
        cached_results = {
          collection_ids: paged_comment_threads.map(&:id),
          num_pages: num_pages,
          page: page,
        }
        Sinatra::Application.cache.set(memcached_key, cached_results, CommentService.config[:cache_timeout][:threads_query].to_i)
      end
      
      {
        collection: paged_comment_threads.map{|t| t.to_hash(recursive: bool_recursive, user_id: params["user_id"])},
        num_pages: num_pages,
        page: page,
      }.to_json
    end
  end

  def author_contents_only(contents, author_id)
    contents.map do |content|
      content['children'] = author_contents_only(content['children'], author_id)
      if content['children'].length > 0 or \
          (content['user_id'] == author_id and not content['anonymous'] and not content['anonymous_to_peers'])
        content
      else
        nil
      end
    end.compact
  end

  def notifications_by_date_range_and_user_ids start_date_time, end_date_time, user_ids  
    #given a date range and a user, find all of the notifiable content
    #key by thread id, and return notification messages for each user

    #first, find the subscriptions for the users
    subscriptions = Subscription.where(:subscriber_id.in => user_ids)

    #get the thhread ids
    thread_ids = subscriptions.collect{|t| t.source_id}.uniq

    #find all the comments
    comments = Comment.by_date_range_and_thread_ids start_date_time, end_date_time, thread_ids

    #and get the threads too, b/c we'll need them for the title
    thread_map = Hash[CommentThread.where(:_id.in => thread_ids).all.map { |t| [t.id, t] }]

    #now build a thread to users subscription map
    subscriptions_map = {}
    subscriptions.each do |s|
      if not subscriptions_map.keys.include? s.source_id.to_s
        subscriptions_map[s.source_id.to_s] = []
      end
      subscriptions_map[s.source_id] << s.subscriber_id
    end

    #notification map will be user => course => thread => [comment bodies]

    notification_map = {}

    comments.each do |c|
      user_ids = subscriptions_map[c.comment_thread_id.to_s]
      user_ids.each do |u|
        if not notification_map.keys.include? u
          notification_map[u] = {}
        end

        if not notification_map[u].keys.include? c.course_id
          notification_map[u][c.course_id] = {}
        end

        if not notification_map[u][c.course_id].include? c.comment_thread_id.to_s
          t = notification_map[u][c.course_id][c.comment_thread_id.to_s] = {}
          t["content"] = []
          t["title"] = thread_map[c.comment_thread_id].title
        else
          t = notification_map[u][c.course_id][c.comment_thread_id.to_s]
        end

        content_obj = {}
        content_obj["username"] = c.author_with_anonymity(:username, "(anonymous)")
        content_obj["updated_at"] = c.updated_at
        t["content"] << content_obj

      end
    end

    notification_map.to_json

  end

end
