put "#{APIPREFIX}/threads/:thread_id/pin" do |thread_id|
  pin thread
end

put "#{APIPREFIX}/threads/:thread_id/unpin" do |thread_id|
  unpin thread
end

