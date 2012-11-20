put "#{APIPREFIX}/comments/:comment_id/abuse_flags" do |comment_id|
  flag_as_abuse comment
end

put "#{APIPREFIX}/threads/:thread_id/abuse_flags" do |thread_id|
  flag_as_abuse thread
end


delete "#{APIPREFIX}/comments/:comment_id/abuse_flags" do |comment_id|
  undo_flag_as_abuse comment
end

delete "#{APIPREFIX}/comments/:thread_id/abuse_flags" do |thread_id|
  undo_flag_as_abuse thread
end


put "#{APIPREFIX}/comments/:comment_id/spoiler_flags" do |comment_id|
  flag_as_spoiler comment
end

put "#{APIPREFIX}/comments/:thread_id/spoiler_flags" do |thread_id|
  flag_as_spoiler thread
end


delete "#{APIPREFIX}/comments/:comment_id/spoiler_flags" do |comment_id|
  undo_flag_as_spoiler comment
end

delete "#{APIPREFIX}/comments/:thread_id/spoiler_flags" do |thread_id|
  undo_flag_as_spoiler thread
end

