def get_thread_ids(context, group_ids, local_params, search_text)
  filters = []
  filters.push({term: {commentable_id: local_params['commentable_id']}}) if local_params['commentable_id']
  filters.push({terms: {commentable_id: local_params['commentable_ids'].split(',')}}) if local_params['commentable_ids']
  filters.push({term: {course_id: local_params['course_id']}}) if local_params['course_id']

  filters.push({or: [
      {not: {exists: {field: :context}}},
      {term: {context: context}}
  ]})

  unless group_ids.empty?
    filters.push(
        {
            or: [
                {:not => {:exists => {:field => :group_id}}},
                {:terms => {:group_id => group_ids}}
            ]
        }
    )
  end

  self.class.trace_execution_scoped(['Custom/get_search_threads/es_search']) do
    body = {
        size: CommentService.config['max_deep_search_comment_count'].to_i,
        sort: [
            {updated_at: :desc}
        ],
        query: {
            multi_match: {
                query: search_text,
                fields: [:title, :body],
                operator: :AND
            },
            filtered: {
                filter: {
                    and: filters
                }
            }
        }
    }

    response = Elasticsearch::Model.client.search(index: Content::ES_INDEX_NAME, body: body)

    thread_ids = Set.new
    response['hits']['hits'].each do |hit|
      case hit['_type']
        when CommentThread.document_type
          thread_ids.add(hit['_id'])
        when Comment.document_type
          thread_ids.add(hit['_source']['comment_thread_id'])
        else
          # There shouldn't be any other document types. Nevertheless, ignore them, if they are present.
          next
      end
    end
    thread_ids
  end
end

def get_suggested_text(search_text)
  body = {
      suggestions: {
          text: search_text,
          phrase: {
              field: :_all
          }
      }
  }
  response = Elasticsearch::Model.client.suggest(index: Content::ES_INDEX_NAME, body: body)
  suggestions = response.fetch('suggestions', [])
  if suggestions.length > 0
    options = suggestions[0]['options']
    if options.length > 0
      return options[0]['text']
    end
  end

  nil
end

def get_threads(context, group_ids, local_params, search_text)
  # Because threads and comments are currently separate unrelated documents in
  # Elasticsearch, we must first query for all matching documents, then
  # extract the set of thread ids, and then sort the threads by the specified
  # criteria and paginate. For performance reasons, we currently limit the
  # number of documents considered (ordered by update recency), which means
  # that matching threads can be missed if the search terms are very common.
  thread_ids = get_thread_ids(context, group_ids, local_params, search_text)
  corrected_text = nil

  if thread_ids.empty?
    # Sadly, Elasticsearch does not have a facility for computing suggestions
    # with respect to a filter. It would be expensive to determine the best
    # suggestion with respect to our filter parameters, so we simply re-query
    # with the top suggestion. If that has no results, then we return no results
    # and no correction.
    corrected_text = get_suggested_text(search_text)
    thread_ids = get_thread_ids(context, group_ids, local_params, corrected_text) if corrected_text
    corrected_text = nil if thread_ids.empty?
  end

  result_obj = handle_threads_query(
      CommentThread.in({_id: thread_ids.to_a}),
      local_params['user_id'],
      local_params['course_id'],
      group_ids,
      value_to_boolean(local_params['flagged']),
      value_to_boolean(local_params['unread']),
      value_to_boolean(local_params['unanswered']),
      local_params['sort_key'],
      local_params['sort_order'],
      local_params['page'],
      local_params['per_page'],
      context
  )

  unless result_obj.empty?
    result_obj[:corrected_text] = corrected_text
    # NOTE this reflects the total results from ES, but does not consider
    # any post-filtering that might happen (e.g. unread, flagged...) before
    # results are shown to the user.
    result_obj[:total_results] = thread_ids.size
  end

  result_obj.to_json
end

get "#{APIPREFIX}/search/threads" do
  local_params = params # Necessary for params to be available inside blocks
  group_ids = get_group_ids_from_params(local_params)
  context = local_params["context"] ? local_params["context"] : "course"
  search_text = local_params["text"]
  if !search_text
    '{}'
  else


    get_threads(context, group_ids, local_params, search_text)
  end
end
