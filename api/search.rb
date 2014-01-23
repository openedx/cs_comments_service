require 'new_relic/agent/method_tracer'

get "#{APIPREFIX}/search/threads" do

  sort_key_mapper = {
    "date" => :created_at,
    "activity" => :last_activity_at,
    "votes" => :votes_point,
    "comments" => :comment_count,
  }

  sort_order_mapper = {
    "desc" => :desc,
    "asc" => :asc,
  }

  sort_key = sort_key_mapper[params["sort_key"]]
  sort_order = sort_order_mapper[params["sort_order"]]

  sort_keyword_valid = (!params["sort_key"] && !params["sort_order"] || sort_key && sort_order)

  if (!params["text"] && !params["commentable_ids"]) || !sort_keyword_valid
    {}.to_json
  else
    page = (params["page"] || DEFAULT_PAGE).to_i
    per_page = (params["per_page"] || DEFAULT_PER_PAGE).to_i
    # for multi commentable searching
    params["commentable_ids"] = params["commentable_ids"].split(',') if params["commentable_ids"]
    options = {
      sort_key: sort_key,
      sort_order: sort_order,
      page: page,
      per_page: per_page,
    }

    results = CommentThread.perform_search(params, options)

    if page > results.total_pages #TODO find a better way for this
      results = CommentThread.perform_search(params, options.merge(page: results.total_pages))
    end

    if results.length == 0
      collection = []
    else
      pres_threads = ThreadSearchResultsPresenter.new(
        results,
        params[:user_id] ? user : nil,
        params[:course_id] || results.first.course_id
      )
      collection = pres_threads.to_hash
    end

    num_pages = results.total_pages
    page = [num_pages, [1, page].max].min
    json_output = nil
    self.class.trace_execution_scoped(['Custom/get_search_threads/json_serialize']) do
      json_output = {
        collection: collection,
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
