require_relative 'thread'
require_relative 'thread_utils'

class ThreadListPresenter

  def initialize(threads, user, course_id, count_flagged=false)
    read_states = ThreadUtils.get_read_states(threads, user, course_id)
    threads_endorsed = ThreadUtils.get_endorsed(threads)
    if count_flagged
      threads_flagged = ThreadUtils.get_abuse_flagged_count(threads)
    else
      threads_flagged = Hash.new
    end
    @presenters = threads.map do |thread|
      thread_key = thread._id.to_s
      is_read, unread_count = read_states.fetch(thread_key, [false, thread.comment_count])
      is_endorsed = threads_endorsed.fetch(thread_key, false)
      abuse_flagged_count = threads_flagged.fetch(thread_key, nil)
      ThreadPresenter.new(thread, user, is_read, unread_count, is_endorsed, abuse_flagged_count)
    end
  end

  def to_hash
    @presenters.map { |p| p.to_hash }
  end

end
