put "#{APIPREFIX}/threads/:thread_id/abuse_flags" do |thread_id|
  flag_as_abuse thread
end

put "#{APIPREFIX}/threads/:thread_id/abuse_unflags" do |thread_id|
  un_flag_as_abuse thread
end

