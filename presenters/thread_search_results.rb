require_relative 'thread_list'

class ThreadSearchResultsPresenter < ThreadListPresenter

  alias :super_to_hash :to_hash

  def initialize(search_results, user, course_id)
    @search_result_map = Hash[search_results.map { |t| [t.id, t] }]
    threads = CommentThread.where(id: {"$in" => @search_result_map.keys}).to_a
    # reorder fetched threads to match the original result order
    threads = Hash[threads.map { |t| [t._id.to_s, t] }].values_at *search_results.map { |t| t.id }
    super(threads, user, course_id)
  end

  def to_hash
    super_to_hash.each do |thread_hash|
      thread_key = thread_hash['id'].to_s
      highlight = @search_result_map[thread_key].highlight || {}
      thread_hash["highlighted_body"] = (highlight[:body] || []).first || thread_hash["body"]
      thread_hash["highlighted_title"] = (highlight[:title] || []).first || thread_hash["title"]
    end
  end

end
