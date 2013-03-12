put "#{APIPREFIX}/threads/:thread_id/pin" do |thread_id|
  pin thread
end

put "#{APIPREFIX}/threads/:thread_id/unpin" do |thread_id|
  unpin thread
end

put "#{APIPREFIX}/comments/:comment_id/pin" do |thread_id|
  pin comment
end

put "#{APIPREFIX}/comments/:comment_id/unpin" do |thread_id|
  unpin comment
end