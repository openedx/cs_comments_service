require 'new_relic/agent/method_tracer'

helpers do

  def commentable
    @commentable ||= Commentable.find(params[:commentable_id])
  end

  def user # TODO handle 404 if integrated user service
    raise ArgumentError, t(:user_id_is_required) unless @user || params[:user_id]
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
      raise ArgumentError, t(:source_type_must_be_user_thread_or_other)
    end
  end

  def vote_for(obj)
    raise ArgumentError, t(:user_id_is_required) unless user
    raise ArgumentError, t(:value_is_required) unless params["value"]
    raise ArgumentError, t(:value_is_invalid) unless %w[up down].include? params["value"]
    user.vote(obj, params["value"].to_sym)
    obj.reload.to_hash.to_json
  end

  def flag_as_abuse(obj)
    raise ArgumentError, t(:user_id_is_required) unless user
    obj.abuse_flaggers << user.id unless obj.abuse_flaggers.include? user.id
    obj.save
    obj.reload.to_hash.to_json
  end
  
  def un_flag_as_abuse(obj)
    raise ArgumentError, t(:user_id_is_required) unless user
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
    raise ArgumentError, t(:user_id_is_required) unless user
    if user.voted?(obj)
      user.unvote(obj)
    end
    obj.reload.to_hash.to_json
  end
  

  def pin(obj)
    raise ArgumentError, t(:user_id_is_required) unless user
    obj.pinned = true
    obj.save
    obj.reload.to_hash.to_json
  end
  
  def unpin(obj)
    raise ArgumentError, t(:user_id_is_required) unless user
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

  def handle_threads_query(
    comment_threads,
    user_id,
    course_id,
    group_ids,
    filter_flagged,
    filter_unread,
    filter_unanswered,
    sort_key,
    sort_order,
    page,
    per_page,
    context=:course
  )

    context_threads = comment_threads.where({:context => context})

    if not group_ids.empty?
      group_threads = get_group_id_criteria(comment_threads, group_ids)
      comment_threads = comment_threads.all_of(context_threads.selector, group_threads.selector)
    else
      comment_threads = context_threads
    end

    if filter_flagged
      self.class.trace_execution_scoped(['Custom/handle_threads_query/find_flagged']) do
        # TODO replace with aggregate query?
        comment_ids = Comment.where(:course_id => course_id).
          where(:abuse_flaggers.ne => [], :abuse_flaggers.exists => true).
          collect{|c| c.comment_thread_id}.uniq
          
        thread_ids = comment_threads.where(:abuse_flaggers.ne => [], :abuse_flaggers.exists => true).
          collect{|c| c.id}

        comment_threads = comment_threads.in({"_id" => (comment_ids + thread_ids).uniq})
      end
    end

    if filter_unanswered
      self.class.trace_execution_scoped(['Custom/handle_threads_query/find_unanswered']) do
        endorsed_thread_ids = Comment.where(:course_id => course_id).
          where(:parent_id.exists => false, :endorsed => true).
          collect{|c| c.comment_thread_id}.uniq
          
        comment_threads = comment_threads.where({"thread_type" => :question}).nin({"_id" => endorsed_thread_ids})
      end
    end

    sort_criteria = get_sort_criteria(sort_key, sort_order)
    if not sort_criteria
      {}
    else
      request_user = user_id ? user : nil
      page = (page || DEFAULT_PAGE).to_i
      per_page = (per_page || DEFAULT_PER_PAGE).to_i

      comment_threads = comment_threads.order_by(sort_criteria)

      if request_user and filter_unread
        # Filter and paginate based on user read state.  Requires joining a subdocument of the
        # user object with documents in the contents collection, which has to be done in memory.
        read_dates = {}
        read_state = request_user.read_states.where(:course_id => course_id).first
        if read_state
          read_dates = read_state["last_read_times"].to_hash
        end

        threads = []
        skipped = 0
        to_skip = (page - 1) * per_page
        has_more = false
        # batch_size is used to cap the number of documents we might load into memory at any given time
        comment_threads.batch_size(CommentService.config["manual_pagination_batch_size"].to_i).each do |thread|
         thread_key = thread._id.to_s
          if !read_dates.has_key?(thread_key) || read_dates[thread_key] < thread.last_activity_at
            if skipped >= to_skip
              if threads.length == per_page
                has_more = true
                break
              end
              threads << thread
            else
              skipped += 1
            end
          end
        end

        # The following trick makes frontend pagers work without recalculating
        # the number of all unread threads per user on every request (since the number
        # of threads in a course could be tens or hundreds of thousands).  It has the 
        # effect of showing that there's always just one more page of results, until
        # there definitely are no more pages.  This is really only acceptable for pagers
        # that don't actually reveal the total number of pages to the user onscreen.
        num_pages = has_more ? page + 1 : page
      else
        # let the installed paginator library handle pagination
        num_pages = [1, (comment_threads.count / per_page.to_f).ceil].max
        page = [1, page].max
        threads = comment_threads.paginate(:page => page, :per_page => per_page).to_a
      end
      
      if threads.length == 0
        collection = []
      else
        pres_threads = ThreadListPresenter.new(threads, request_user, course_id)
        collection = pres_threads.to_hash
      end
      {collection: collection, num_pages: num_pages, page: page, thread_count: comment_threads.count}
    end
  end

  # Given query params, return sort criteria appropriate for passing to the
  # order_by function of a Mongoid query. Returns nil if params are not valid.
  def get_sort_criteria(sort_key, sort_order)
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

    sort_key = sort_key_mapper[params["sort_key"] || "date"]
    sort_order = sort_order_mapper[params["sort_order"] || "desc"]

    if sort_key && sort_order
      sort_criteria = [[:pinned, :desc], [sort_key, sort_order]]
      if ![:created_at, :last_activity_at].include? sort_key
        sort_criteria << [:created_at, :desc]
      end
      sort_criteria
    else
      nil
    end
  end

  def get_group_ids_from_params(params)
    if params["group_id"] and params["group_ids"]
      raise ArgumentError, t(:cannot_specify_group_id_and_group_ids)
    end
    group_ids = []
    if params["group_id"]
      group_ids << params["group_id"].to_i
    elsif params["group_ids"]
      group_ids.concat(params["group_ids"].split(",").map(&:to_i))
    end
    group_ids
  end

  def get_group_id_criteria(threads, group_ids)
    if group_ids.length > 1
      threads.any_of(
        {"group_id" => {"$in" => group_ids}},
        {"group_id" => {"$exists" => false}},
      )
    else
      threads.any_of(
        {"group_id" => group_ids[0]},
        {"group_id" => {"$exists" => false}},
      )
    end
  end

  def notifications_by_date_range_and_user_ids(start_date_time, end_date_time, user_ids)
    #given a date range and a user, find all of the notifiable content
    #key by thread id, and return notification messages for each user

    #first, find the subscriptions for the users
    subscriptions = Subscription.where(:subscriber_id.in => user_ids)

    #get the thread ids
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
      current_thread = thread_map[c.comment_thread_id]

      #do not include threads or comments who have current or historical abuse flags
      if current_thread.abuse_flaggers.to_a.empty? and 
        current_thread.historical_abuse_flaggers.to_a.empty? and 
        c.abuse_flaggers.to_a.empty? and 
        c.historical_abuse_flaggers.to_a.empty?
        
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
              t["title"] = current_thread.title
              t["commentable_id"] = current_thread.commentable_id
              unless current_thread.group_id.nil?
                t["group_id"] = current_thread.group_id
              end
            else
              t = notification_map[u][c.course_id][c.comment_thread_id.to_s]
            end

            content_obj = {}
            content_obj["username"] = c.author_with_anonymity(:username, t(:anonymous))
            content_obj["updated_at"] = c.updated_at
            content_obj["body"] = c.body
            t["content"] << content_obj
          end
      end
    end

    notification_map.to_json

  end

  def filter_blocked_content body
    begin
      normalized_body = body.strip.downcase.gsub(/[^a-z ]/, '').gsub(/\s+/, ' ')
      hash = Digest::MD5.hexdigest(normalized_body)
    rescue
      # body was nil, or the hash function failed somehow - never mind
      return
    end
    if CommentService.blocked_hashes.include? hash then
      msg = t(:blocked_content_with_body_hash, :hash => hash) 
      logger.warn msg
      error 503, [msg].to_json
    end
  end
  
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :user
  add_method_tracer :thread
  add_method_tracer :comment
  add_method_tracer :flag_as_abuse
  add_method_tracer :un_flag_as_abuse
  add_method_tracer :handle_threads_query

end
