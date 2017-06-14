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
            bool: {
                should: [
                    {:not => {:exists => {:field => :group_id}}},
                    {:terms => {:group_id => group_ids}}
                ]
            }
        }
    )
  end

  body = {
      size: CommentService.config['max_deep_search_comment_count'].to_i,
      sort: [
          {updated_at: :desc}
      ],
      query: {
          filtered: {
              query: {
                  multi_match: {
                      query: search_text,
                      fields: [:title, :body],
                      operator: :AND
                  }
              },
              filter: {
                  bool: {
                      must: filters
                  }
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

error Sinatra::Param::InvalidParameterError do
  # NOTE (CCB): The current behavior of the service is to return a seemingly positive response
  # for an invalid request. In the future the API's contract should be modified so that HTTP 400
  # is returned. This informs the client that the request was invalid, rather than having to guess
  # about an empty response body.
  [200, '{}']
end

get "#{APIPREFIX}/search/threads" do
  param :text, String, required: true
  param :context, String, default: 'course'
  param :sort_key, String, in: %w(activity comments date votes), transform: :downcase

  local_params = params # Necessary for params to be available inside blocks
  group_ids = get_group_ids_from_params(local_params)
  get_threads(params[:context], group_ids, local_params, params[:text])
end
