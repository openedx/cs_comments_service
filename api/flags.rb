put "#{APIPREFIX}/comments/:comment_id/abuse_flags" do |comment_id|
  flag_as_abuse comment
end

put "#{APIPREFIX}/threads/:thread_id/abuse_unflags" do |thread_id|
  un_flag_as_abuse thread
end


delete "#{APIPREFIX}/comments/:comment_id/abuse_flags" do |comment_id|
  undo_flag_as_abuse comment
end

delete "#{APIPREFIX}/comments/:thread_id/abuse_flags" do |thread_id|
  undo_flag_as_abuse thread
end
