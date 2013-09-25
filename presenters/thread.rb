require 'new_relic/agent/method_tracer'

class ThreadPresenter

  def initialize(comment_threads, user, course_id)
    @threads = comment_threads
    @user = user
    @course_id = course_id
    @read_dates = nil # Hash, sparse, thread_key (str) => date
    @unread_counts = nil # Hash, sparse, thread_key (str) => int
    @endorsed_threads = nil # Hash, sparse, thread_key (str) => bool
    load_aggregates
  end

  def load_aggregates
    @read_dates = {}
    if @user
      read_state = @user.read_states.where(:course_id => @course_id).first
      if read_state
        @read_dates = read_state["last_read_times"].to_hash
      end
    end

    @unread_counts = {}
    @endorsed_threads = {}

    thread_ids = @threads.collect {|t| t._id}
    Comment.collection.aggregate(
      {"$match" => {"comment_thread_id" => {"$in" => thread_ids}, "endorsed" => true}},
      {"$group" => {"_id" => "$comment_thread_id"}}
    ).each do |res| 
      @endorsed_threads[res["_id"].to_s] = true 
    end

    @threads.each do |t|
      thread_key = t._id.to_s
      if @read_dates.has_key? thread_key
        @unread_counts[thread_key] = Comment.collection.where(
          :comment_thread_id => t._id,
          :author_id => {"$ne" => @user.id},
          :updated_at => {"$gte" => @read_dates[thread_key]}
          ).count
      end
    end
  end

  def to_hash thread, with_comments=false
    thread_key = thread._id.to_s 
    h = thread.to_hash
    if @user
      cnt_unread = @unread_counts.fetch(thread_key, thread.comment_count)
      h["unread_comments_count"] = cnt_unread
      h["read"] = @read_dates.has_key?(thread_key) && @read_dates[thread_key] >= thread.updated_at
    else
      h["unread_comments_count"] = thread.comment_count
      h["read"] = false
    end
    h["endorsed"] = @endorsed_threads.fetch(thread_key, false)
    h = merge_comments_recursive(h) if with_comments
    h
  end

  def to_hash_array with_comments=false
    @threads.map {|t| to_hash(t, with_comments)}
  end

  def merge_comments_recursive thread_hash
    thread_id = thread_hash["id"]
    root = thread_hash = thread_hash.merge("children" => [])
    # Content model is used deliberately here (instead of Comment), to work with sparse index
    rs = Content.where(comment_thread_id: thread_id).order_by({"sk"=> 1})
    ancestry = [thread_hash]
    # weave the fetched comments into a single hierarchical doc
    rs.each do | comment |
      thread_hash = comment.to_hash.merge("children" => [])
      parent_id = comment.parent_id || thread_id
      found_parent = false
      while ancestry.length > 0 do
        if parent_id == ancestry.last["id"] then
          # found the children collection to which this comment belongs
          ancestry.last["children"] << thread_hash
          ancestry << thread_hash
          found_parent = true
          break
        else
          # try again with one level back in the ancestry til we find the parent
          ancestry.pop
          next
        end
      end 
      if not found_parent
        # if we arrive here, it means a parent_id somewhere in the result set
        # is pointing to an invalid place.  reset the ancestry search path.
        ancestry = [root]
      end
    end
    ancestry.first 
  end

  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :load_aggregates
  add_method_tracer :to_hash
  add_method_tracer :to_hash_array
  add_method_tracer :merge_comments_recursive

end
