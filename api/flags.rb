put "#{APIPREFIX}/threads/:thread_id/abuse_flag" do |thread_id|
  flag_as_abuse thread
end

put "#{APIPREFIX}/threads/:thread_id/abuse_unflag" do |thread_id|
  un_flag_as_abuse thread
end

put "#{APIPREFIX}/comments/:comment_id/abuse_flag" do |comment_id|
  flag_as_abuse comment
end

put "#{APIPREFIX}/comments/:comment_id/abuse_unflag" do |comment_id|
  un_flag_as_abuse comment
end
