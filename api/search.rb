get "#{APIPREFIX}/search/threads" do
  local_params = params # Necessary for params to be available inside blocks
  group_ids = get_group_ids_from_params(local_params)
  context = local_params["context"] ? local_params["context"] : "course"
  search_text = local_params["text"]
  if !search_text
    {}.to_json
  else
    # Because threads and comments are currently separate unrelated documents in
    # Elasticsearch, we must first query for all matching documents, then
    # extract the set of thread ids, and then sort the threads by the specified
    # criteria and paginate. For performance reasons, we currently limit the
    # number of documents considered (ordered by update recency), which means
    # that matching threads can be missed if the search terms are very common.

    get_matching_thread_ids = lambda do |search_text|
      self.class.trace_execution_scoped(["Custom/get_search_threads/es_search"]) do
        search = Tire.search Content::ES_INDEX_NAME do
          query do
            match [:title, :body], search_text, :operator => "AND"
            filtered do
              filter :term, :commentable_id => local_params["commentable_id"] if local_params["commentable_id"]
              filter :terms, :commentable_id => local_params["commentable_ids"].split(",") if local_params["commentable_ids"]
              filter :term, :course_id => local_params["course_id"] if local_params["course_id"]
              filter :or, [
                {:not => {:exists => {:field => :context}}},
                {:term => {:context => context}}
              ]

              if not group_ids.empty?
                if group_ids.length > 1
                  group_id_criteria = {:terms => {:group_id => group_ids}}
                else
                  group_id_criteria = {:term => {:group_id => group_ids[0]}}
                end

                filter :or, [
                  {:not => {:exists => {:field => :group_id}}},
                  group_id_criteria
                ]
              end

            end
          end
          sort do
            by "updated_at", "desc"
          end
          size CommentService.config["max_deep_search_comment_count"].to_i
        end
        thread_ids = Set.new
        search.results.each do |content|
          case content.type
          when "comment_thread"
            thread_ids.add(content.id)
          when "comment"
            thread_ids.add(content.comment_thread_id)
          end
        end
        thread_ids
      end
    end

    # Sadly, Elasticsearch does not have a facility for computing suggestions
    # with respect to a filter. It would be expensive to determine the best
    # suggestion with respect to our filter parameters, so we simply re-query
    # with the top suggestion. If that has no results, then we return no results
    # and no correction.
    thread_ids = get_matching_thread_ids.call(search_text)
    corrected_text = nil
    if thread_ids.empty?
      suggest = Tire.suggest Content::ES_INDEX_NAME do
        suggestion "" do
          text search_text
          phrase :_all
        end
      end
      corrected_text = suggest.results.texts.first
      thread_ids = get_matching_thread_ids.call(corrected_text) if corrected_text
      corrected_text = nil if thread_ids.empty?
    end

    result_obj = handle_threads_query(
      CommentThread.in({"_id" => thread_ids.to_a}),
      local_params["user_id"],
      local_params["course_id"],
      group_ids,
      value_to_boolean(local_params["flagged"]),
      value_to_boolean(local_params["unread"]),
      value_to_boolean(local_params["unanswered"]),
      local_params["sort_key"],
      local_params["sort_order"],
      local_params["page"],
      local_params["per_page"],
      context
    )
    if !result_obj.empty?
      result_obj[:corrected_text] = corrected_text
      # NOTE this reflects the total results from ES, but does not consider
      # any post-filtering that might happen (e.g. unread, flagged...) before
      # results are shown to the user.
      result_obj[:total_results] = thread_ids.size
    end
    result_obj.to_json
  end
end
