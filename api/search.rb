require 'new_relic/agent/method_tracer'

get "#{APIPREFIX}/search/threads" do
  local_params = params # Necessary for params to be available inside blocks
  sort_criteria = get_sort_criteria(local_params)

  if !local_params["text"] || !sort_criteria
    {}.to_json
  else
    page = (local_params["page"] || DEFAULT_PAGE).to_i
    per_page = (local_params["per_page"] || DEFAULT_PER_PAGE).to_i

    # Because threads and comments are currently separate unrelated documents in
    # Elasticsearch, we must first query for all matching documents, then
    # extract the set of thread ids, and then sort the threads by the specified
    # criteria and paginate. For performance reasons, we currently limit the
    # number of documents considered (ordered by update recency), which means
    # that matching threads can be missed if the search terms are very common.

    thread_ids = Set.new
    self.class.trace_execution_scoped(["Custom/get_search_threads/es_search"]) do
      search = Tire.search Content::ES_INDEX_NAME do
        query do
          match [:title, :body], local_params["text"]
          filtered do
            filter :term, :commentable_id => local_params["commentable_id"] if local_params["commentable_id"]
            filter :terms, :commentable_id => local_params["commentable_ids"].split(",") if local_params["commentable_ids"]
            filter :term, :course_id => local_params["course_id"] if local_params["course_id"]
            if local_params["group_id"]
              filter :or, [
                {:not => {:exists => {:field => :group_id}}},
                {:term => {:group_id => local_params["group_id"]}}
              ]
            end
          end
        end
        sort do
          by "updated_at", "desc"
        end
        size CommentService.config["max_deep_search_comment_count"].to_i
      end
      search.results.each do |content|
        case content.type
        when "comment_thread"
          thread_ids.add(content.id)
        when "comment"
          thread_ids.add(content.comment_thread_id)
        end
      end
    end

    results = nil
    self.class.trace_execution_scoped(["Custom/get_search_threads/mongo_sort_page"]) do
      results = CommentThread.
        where(:id.in => thread_ids.to_a).
        order_by(sort_criteria).
        page(page).
        per(per_page).
        to_a
    end
    total_results = thread_ids.size
    num_pages = (total_results + per_page - 1) / per_page

    if results.length == 0
      collection = []
    else
      pres_threads = ThreadListPresenter.new(
        results,
        local_params[:user_id] ? user : nil,
        local_params[:course_id] || results.first.course_id
      )
      collection = pres_threads.to_hash
    end

    json_output = nil
    self.class.trace_execution_scoped(['Custom/get_search_threads/json_serialize']) do
      json_output = {
        collection: collection,
        total_results: total_results,
        num_pages: num_pages,
        page: page,
      }.to_json
    end
    json_output
  end
end

get "#{APIPREFIX}/search/threads/more_like_this" do
  CommentThread.tire.search page: 1, per_page: 5, load: true do |search|
    search.query do |query|
      query.more_like_this params["text"], fields: ["title", "body"], min_doc_freq: 1, min_term_freq: 1
    end
  end.results.map(&:to_hash).to_json
end

get "#{APIPREFIX}/search/threads/recent_active" do

  return [].to_json if not params["course_id"]

  follower_id = params["follower_id"]
  from_time = {
    "today" => Date.today.to_time,
    "this_week" => Date.today.to_time - 1.weeks,
    "this_month" => Date.today.to_time - 1.months,
  }[params["from_time"] || "this_week"]

  query_params = {}
  query_params["course_id"] = params["course_id"] if params["course_id"]
  query_params["commentable_id"] = params["commentable_id"] if params["commentable_id"]

  comment_threads = if follower_id
    User.find(follower_id).subscribed_threads
  else
    CommentThread.all
  end

  comment_threads.where(query_params.merge(:last_activity_at => {:$gte => from_time})).order_by(:last_activity_at.desc).limit(5).to_a.map(&:to_hash).to_json
end
