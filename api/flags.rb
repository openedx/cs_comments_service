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

get "#{APIPREFIX}/flagged_threads" do
  flagged = Content.flagged
  page = (params["page"] || DEFAULT_PAGE).to_i
  per_page = (params["per_page"] || DEFAULT_PER_PAGE).to_i
  num_pages = [1, (flagged.count / per_page.to_f).ceil].max
  page = [1, page].max
  flagged_array = flagged.page(page).per(per_page).to_a
  flagged_threads = []
  flagged_array.each do |f|
    flagged_threads << {
      course_id: f.course_id,
      commentable_id: f.commentable_id,
      comment_thread_id: f.comment_thread_id,
    }
  end
  flagged_threads.to_json
end
