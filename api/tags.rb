get "#{APIPREFIX}/threads/tags" do
  CommentThread.tags.to_json
end

get "#{APIPREFIX}/threads/tags/autocomplete" do
  CommentThread.tags_autocomplete(params["value"].strip, max: 5, sort_by_count: true).map(&:first).to_json
end
