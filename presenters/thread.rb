require 'logger'
require_relative 'thread_utils'

class ThreadPresenter

  def self.factory(thread, user, count_flagged=false)
    # use when working with one thread at a time.  fetches extended /
    # derived attributes from the db and explicitly initializes an instance.
    course_id = thread.course_id
    thread_key = thread._id.to_s
    is_read, unread_count = ThreadUtils
                              .get_read_states([thread], user, course_id)
                              .fetch(thread_key, [false, thread.comment_count])
    is_endorsed = ThreadUtils.get_endorsed([thread]).fetch(thread_key, false)
    abuse_flagged_count = count_flagged ?
                            ThreadUtils.get_abuse_flagged_count([thread]).fetch(thread_key, nil) :
                            nil
    self.new thread, user, is_read, unread_count, is_endorsed, abuse_flagged_count
  end

  def initialize(thread, user, is_read, unread_count, is_endorsed, abuse_flagged_count)
    # generally not intended for direct use.  instantiated by self.factory or
    # by thread list presenters.
    @thread = thread
    @user = user
    @is_read = is_read
    @unread_count = unread_count
    @is_endorsed = is_endorsed
    @abuse_flagged_count = abuse_flagged_count
  end

  def to_hash(
    with_responses=false,
    resp_skip=0,
    resp_limit=nil,
    recursive=true,
    flagged_comments=false,
    reverse_order=false
  )
    raise ArgumentError unless resp_skip >= 0
    raise ArgumentError unless resp_limit.nil? or resp_limit >= 1
    h = @thread.to_hash
    h["read"] = @is_read
    h["unread_comments_count"] = @unread_count
    h["endorsed"] = @is_endorsed || false
    unless @abuse_flagged_count.nil?
      h["abuse_flagged_count"] = @abuse_flagged_count
    end
    sorting_key_order = reverse_order ? -1 : 1
    if with_responses
      if @thread.thread_type.discussion? && resp_skip == 0 && resp_limit.nil?
        if recursive
          content = Comment.where(comment_thread_id: @thread._id).order_by({"sk" => sorting_key_order})
        else
          content = Comment.where(comment_thread_id: @thread._id, "parent_ids" => []).order_by({"sk" => sorting_key_order})
        end
        if flagged_comments
          content = content.where(:abuse_flaggers.nin => [nil, []])
        end
        h["children"] = merge_response_content(content)
        h["resp_total"] = content.to_a.select{|d| d.depth == 0 }.length
      else
        responses = Content.where(comment_thread_id: @thread._id).exists(parent_id: false)
        if flagged_comments
          responses = responses.where(:abuse_flaggers.nin => [nil, []])
        end
        case @thread.thread_type
        when "question"
          endorsed_responses = responses.where(endorsed: true)
          non_endorsed_responses = responses.where(endorsed: false)
          endorsed_response_info = get_paged_merged_responses(
            @thread._id,
            endorsed_responses,
            0,
            nil,
            recursive,
            sorting_key_order
          )
          non_endorsed_response_info = get_paged_merged_responses(
            @thread._id,
            non_endorsed_responses,
            resp_skip,
            resp_limit,
            recursive,
            sorting_key_order
          )
          h["endorsed_responses"] = endorsed_response_info["responses"]
          h["non_endorsed_responses"] = non_endorsed_response_info["responses"]
          h["non_endorsed_resp_total"] = non_endorsed_response_info["response_count"]
          h["resp_total"] = non_endorsed_response_info["response_count"] + endorsed_response_info["response_count"]
        when "discussion"
          response_info = get_paged_merged_responses(
            @thread._id,
            responses,
            resp_skip,
            resp_limit,
            recursive,
            sorting_key_order
          )
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
  #     children, if recursive is true)
  #   response_count
  #     The total number of responses
  def get_paged_merged_responses(thread_id, responses, skip, limit, recursive=false, sorting_key_order)
    response_ids = responses.only(:_id).sort({"sk" => sorting_key_order}).to_a.map{|doc| doc["_id"]}
    paged_response_ids = limit.nil? ? response_ids.drop(skip) : response_ids.drop(skip).take(limit)
    if recursive
      content = Comment.where(comment_thread_id: thread_id).
        any_of({:parent_id => {"$in" => paged_response_ids}}, {:id => {"$in" => paged_response_ids}}).
        sort({"sk" => sorting_key_order})
    else
      content = Comment.where(comment_thread_id: thread_id, "parent_ids" => []).
        where({:id => {"$in" => paged_response_ids}}).sort({"sk" => sorting_key_order})
    end
    {"responses" => merge_response_content(content), "response_count" => response_ids.length}
  end

  # Takes content output from Mongoid in a depth-first traversal order and
  # returns an array of first-level response hashes with content represented
  # hierarchically, with a comment's list of children in the key "children".
  def merge_response_content(content)
    top_level = []
    ancestry = []
    orphans = []
    content.each do |item|
      item_hash = item.to_hash.merge!("children" => [])
      if item.parent_id.nil?
        top_level << item_hash
        ancestry = [item_hash]
        # When the content is reversed, we collect orphan items
        # until reach their parent. Here we iterate through
        # orphans and assign as children to the top item.
        unless orphans.empty?
          orphans.each do |orphan|
            if item.id == orphan["parent_id"]
              item_hash["children"] << orphan
            end
          end
          orphans = []
        end
      else
        # "ancestry" can be empty only when the order is reversed.
        if ancestry.empty?
          ancestry << item_hash
          orphans << item_hash
          next
        end

        while ancestry.length > 0 do
          if item.parent_id == ancestry.last["id"]
            ancestry.last["children"] << item_hash
            ancestry << item_hash
            break
          elsif ancestry.length == 1
            # "ancestry" here can equal to 1 only when the order is reversed.
            orphans << item_hash
            ancestry.pop
          else
            ancestry.pop
          end
        end
      end
    end
    top_level
  end
  logger = Logger.new(STDOUT)
  logger.level = Logger::WARN
  begin
    require 'new_relic/agent/method_tracer'
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer :to_hash
    add_method_tracer :merge_response_content
  rescue LoadError
    logger.warn "NewRelic agent library not installed"
  end

end
