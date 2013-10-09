require_relative 'thread'

class ThreadSearchResultPresenter < ThreadPresenter

  alias :super_to_hash :to_hash

  def initialize(search_results, user, course_id)
    @search_result_map = Hash[search_results.map { |t| [t.id, t] }]
    threads = CommentThread.where(id: {"$in" => @search_result_map.keys}).to_a
    # reorder fetched threads to match the original result order
    threads = Hash[threads.map { |t| [t._id.to_s, t] }].values_at *search_results.map { |t| t.id }
    super(threads, user, course_id)
  end

  def to_hash(thread, with_comments=false)
    thread_hash = super_to_hash(thread, with_comments)
    highlight = @search_result_map[thread.id.to_s].highlight || {}
    thread_hash["highlighted_body"] = (highlight[:body] || []).first || thread_hash["body"]
    thread_hash["highlighted_title"] = (highlight[:title] || []).first || thread_hash["title"]
    thread_hash
  end

end
