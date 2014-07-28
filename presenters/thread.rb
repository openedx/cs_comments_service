require_relative 'thread_utils'
require 'new_relic/agent/method_tracer'

class ThreadPresenter

  def self.factory(thread, user)
    # use when working with one thread at a time.  fetches extended / 
    # derived attributes from the db and explicitly initializes an instance.
    course_id = thread.course_id
    thread_key = thread._id.to_s
    is_read, unread_count = ThreadUtils.get_read_states([thread], user, course_id).fetch(thread_key, [false, thread.comment_count])
    is_endorsed = ThreadUtils.get_endorsed([thread]).fetch(thread_key, false)
    self.new thread, user, is_read, unread_count, is_endorsed
  end

  def initialize(thread, user, is_read, unread_count, is_endorsed)
    # generally not intended for direct use.  instantiated by self.factory or
    # by thread list presenters.
    @thread = thread
    @user = user
    @is_read = is_read
    @unread_count = unread_count
    @is_endorsed = is_endorsed
  end

  def to_hash with_responses=false, resp_skip=0, resp_limit=nil
    raise ArgumentError unless resp_skip >= 0
    raise ArgumentError unless resp_limit.nil? or resp_limit >= 1
    h = @thread.to_hash
    h["read"] = @is_read
    h["unread_comments_count"] = @unread_count
    h["endorsed"] = @is_endorsed || false
    if with_responses
      if @thread.thread_type.discussion? && resp_skip == 0 && resp_limit.nil?
        content = Comment.where(comment_thread_id: @thread._id).order_by({"sk" => 1})
        h["children"] = merge_response_content(content)
        h["resp_total"] = content.to_a.select{|d| d.depth == 0 }.length
      else
        responses = Content.where(comment_thread_id: @thread._id).exists(parent_id: false)
        case @thread.thread_type
        when "question"
          endorsed_responses = responses.where(endorsed: true)
          non_endorsed_responses = responses.where(endorsed: false)
          endorsed_response_info = get_paged_merged_responses(@thread._id, endorsed_responses, 0, nil)
          non_endorsed_response_info = get_paged_merged_responses(
            @thread._id,
            non_endorsed_responses,
            resp_skip,
            resp_limit
          )
          h["endorsed_responses"] = endorsed_response_info["responses"]
          h["non_endorsed_responses"] = non_endorsed_response_info["responses"]
          h["non_endorsed_resp_total"] = non_endorsed_response_info["response_count"]
        when "discussion"
          response_info = get_paged_merged_responses(@thread._id, responses, resp_skip, resp_limit)
          h["children"] = response_info["responses"]
          h["resp_total"] = response_info["response_count"]
        end
      end
      h["resp_skip"] = resp_skip
      h["resp_limit"] = resp_limit
    end
    h
  end

  # Given a Mongoid object representing responses, apply pagination and return
  # a hash containing the following:
  #   responses
  #     An array of hashes representing the page of responses (including
  #     children)
  #   response_count
  #     The total number of responses
  def get_paged_merged_responses(thread_id, responses, skip, limit)
    response_ids = responses.only(:_id).sort({"sk" => 1}).to_a.map{|doc| doc["_id"]}
    paged_response_ids = limit.nil? ? response_ids.drop(skip) : response_ids.drop(skip).take(limit)
    content = Comment.where(comment_thread_id: thread_id).
      or({:parent_id => {"$in" => paged_response_ids}}, {:id => {"$in" => paged_response_ids}}).
      sort({"sk" => 1})
    {"responses" => merge_response_content(content), "response_count" => response_ids.length}
  end

  # Takes content output from Mongoid in a depth-first traversal order and
  # returns an array of first-level response hashes with content represented
  # hierarchically, with a comment's list of children in the key "children".
  def merge_response_content(content)
    top_level = []
    ancestry = []
    content.each do |item|
      item_hash = item.to_hash.merge("children" => [])
      if item.parent_id.nil?
        top_level << item_hash
        ancestry = [item_hash]
      else
        while ancestry.length > 0 do
          if item.parent_id == ancestry.last["id"]
            ancestry.last["children"] << item_hash
            ancestry << item_hash
            break
          else
            ancestry.pop
            next
          end
        end
        if ancestry.empty? # invalid parent; ignore item
          next
        end
      end
    end
    top_level
  end

  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :to_hash
  add_method_tracer :merge_response_content

end
