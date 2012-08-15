put "#{APIPREFIX}/comments/:comment_id/votes" do |comment_id|
  vote_for comment
end

delete "#{APIPREFIX}/comments/:comment_id/votes" do |comment_id|
  undo_vote_for comment
end

put "#{APIPREFIX}/threads/:thread_id/votes" do |thread_id|
  vote_for thread
end

delete "#{APIPREFIX}/threads/:thread_id/votes" do |thread_id|
  undo_vote_for thread
end
