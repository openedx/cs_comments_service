require 'logger'

require_relative 'constants'
require_relative '../mongoutil'

class User
  include Mongoid::Document
  include Mongo::Voter

  field :_id, type: String, default: -> { external_id }
  field :external_id, type: String
  field :username, type: String
  field :email, type: String
  field :default_sort_key, type: String, default: "date"

  embeds_many :read_states
  has_many :comments, inverse_of: :author
  has_many :comment_threads, inverse_of: :author
  has_many :activities, class_name: "Notification", inverse_of: :actor
  has_and_belongs_to_many :notifications, inverse_of: :receivers

  validates_presence_of :external_id
  validates_presence_of :username
  validates_uniqueness_of :external_id
  validates_uniqueness_of :username

  index( {external_id: 1}, {unique: true, background: true} )

  logger = Logger.new(STDOUT)
  logger.level = Logger::WARN

  def subscriptions_as_source
    Subscription.where(source_id: id.to_s, source_type: self.class.to_s)
  end

  def subscribed_thread_ids
    Subscription.where(subscriber_id: id.to_s, source_type: "CommentThread").only(:source_id).map(&:source_id)
  end

  def subscribed_threads
    CommentThread.in({"_id" => subscribed_thread_ids})
  end

  def to_hash(params={})
    hash = as_document
      .slice(USERNAME, EXTERNAL_ID)

    if params[:complete]
      hash = hash.merge!("subscribed_thread_ids" => subscribed_thread_ids,
                        "subscribed_commentable_ids" => [], # not used by comment client.  To be removed once removed from comment client.
                        "subscribed_user_ids" => [], # ditto.
                        "follower_ids" => [], # ditto.
                        "id" => id,
                        "upvoted_ids" => upvoted_ids,
                        "downvoted_ids" => downvoted_ids,
                        "default_sort_key" => default_sort_key)
    end

    if params[:course_id]
      if not params[:group_ids].empty?
        # Get threads in either the specified group(s) or posted to all groups (nil).
        specified_groups_or_global = params[:group_ids] << nil
        threads_count = CommentThread.course_context.where(
          author_id: id,
          course_id: params[:course_id],
          group_id: {"$in" => specified_groups_or_global},
          anonymous: false,
          anonymous_to_peers: false
        ).count

        # Note that the comments may have been responses to a thread not started by author_id.

        # comment.standalone_context? gets the context from the parent comment_thread
        # we need to eager load the comment_thread to prevent an N+1 when we iterate through the results
        comment_thread_ids = Comment.includes(:comment_thread).where(
          author_id: id,
          course_id: params[:course_id],
          anonymous: false,
          anonymous_to_peers: false
        ).
        reject{ |comment| comment.standalone_context? }.
        collect{ |comment| comment.comment_thread_id }

        # Filter to the unique thread ids visible to the specified group(s).
        group_comment_thread_ids = CommentThread.where(
          id: {"$in" => comment_thread_ids.uniq},
          group_id: {"$in" => specified_groups_or_global},
        ).collect{|d| d.id}

        # Now filter comment_thread_ids so it only includes things in group_comment_thread_ids
        # (keeping duplicates so the count will be correct).
        comments_count = comment_thread_ids.count{
          |comment_thread_id| group_comment_thread_ids.include?(comment_thread_id)
        }

      else
        threads_count = CommentThread.course_context.where(
          author_id: id,
          course_id: params[:course_id],
          anonymous: false,
          anonymous_to_peers: false
        ).count
        # comment.standalone_context? gets the context from the parent comment_thread
        # we need to eager load the comment_thread to prevent an N+1 when we iterate through the results
        comments_count = Comment.includes(:comment_thread).where(
          author_id: id,
          course_id: params[:course_id],
          anonymous: false,
          anonymous_to_peers: false
        ).reject{ |comment| comment.standalone_context? }.count
      end
      hash = hash.merge!("threads_count" => threads_count, "comments_count" => comments_count)
    end
    hash
  end

  def upvoted_ids
    Content.up_voted_by(self).pluck(:_id)
  end

  def downvoted_ids
    Content.down_voted_by(self).pluck(:_id)
  end

  def followers
    subscriptions_as_source.map(&:subscriber)
  end

  def subscribe(source)
    if source._id == self._id and source.class == self.class
      raise ArgumentError, "Cannot follow oneself"
    else
      reconnect_mongo_primary
      Subscription.find_or_create_by(subscriber_id: self._id.to_s, source_id: source._id.to_s, source_type: source.class.to_s)
    end
  end

  def unsubscribe(source)
    subscription = Subscription.where(subscriber_id: self._id.to_s, source_id: source._id.to_s, source_type: source.class.to_s).first
    subscription.destroy if subscription
    subscription
  end

  def unsubscribe_all
    # Unsubscribe this user from all their subscribed threads across all courses.
    sub_threads = subscribed_threads
    sub_threads.each {|sub_id| unsubscribe(sub_id) }
  end

  def all_comments
    # Returns all comments authored by this user.
    user_comments = Comment.where(author_id: self._id.to_s)
    user_comments
  end

  def all_comment_threads
    # Returns all comment threads authored by this user.
    user_comment_threads = CommentThread.where(author_id: self._id.to_s)
    user_comment_threads
  end

  def retire_comment(comment, retired_username)
    # Retire a single comment and return a bulk action for elasticsearch.
    data = {
        retired_username: retired_username,
        body: RETIRED_BODY
    }
    if comment._type == "CommentThread"
      data[:title] = RETIRED_TITLE
    end
    comment.without_es do
      comment.update!(data)
    end
    # Craft a bulk action for elasticsearch.  This is a little bit of low-level boilerplate which is
    # normally handled by the elasticsearch-rails package, but the high-level API bindings don't include
    # support for bulk requests so we need to do the dirty work ourselves.
    data[:author_username] = retired_username
    {
      update: {
        _index: Content::ES_INDEX_NAME,
        _type: comment.__elasticsearch__.document_type,
        _id: comment._id,
        data: { doc: data }
      }
    }
  end

  def retire_all_content(retired_username)
    # Retire all content authored by this user.
    user_comments = all_comments
    user_comment_threads = all_comment_threads
    user_content = all_comments + all_comment_threads
    # We must avoid sending empty bulk requests, so we wrap the following in a conditional.  Otherwise,
    # Elasticsearch::Model.client.bulk() will blindly pass along an empty string to the bulk API
    # endpoint which causes 400s and cryptic error messages.
    unless user_content.empty?
      # Retire each comment one at a time, deferring any ES updates.
      bulk_data = user_content.map {|comment| retire_comment(comment, retired_username)}
      # Finally, update ES with all the comment changes in one bulk HTTP request.  This is a bit of a time
      # bomb since it might cause the request payload to blow up for that one user with 100k forum posts,
      # but the failure mode before bulking was undeniably worse so at least we're making progress.  ES
      # docs claim that a 10MB payload is a good starting point for a bulk request, which for our use case
      # means blanking out about 36k forum posts.  That's a lot of flame wars for one user!
      Elasticsearch::Model.client.bulk(body: bulk_data)
    end
  end

  def replace_comment_username(comment, new_username)
    # Replace the username of a single comment with the new username
    data = {
      username: new_username
    }
    comment.without_es do
      comment.update!(data)
    end
    {
      update: {
        _index: Content::ES_INDEX_NAME,
        _type: comment.__elasticsearch__.document_type,
        _id: comment._id,
        data: { doc: data }
      }
    }
  end

  def replace_username_in_all_content(new_username)
    # Replaces the username on all content authored by this user
    user_comments = all_comments
    user_comment_threads = all_comment_threads
    user_content = all_comments + all_comment_threads
    unless user_content.empty?
      bulk_data = user_content.map {|comment| replace_comment_username(comment, new_username)}
      Elasticsearch::Model.client.bulk(body: bulk_data)
    end
  end


  def mark_as_read(thread)
    reconnect_mongo_primary
    read_state = read_states.find_or_create_by(course_id: thread.course_id)
    read_state.last_read_times[thread.id.to_s] = Time.now.utc
    read_state.save
  end

  begin
    require 'new_relic/agent/method_tracer'
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer :to_hash
    add_method_tracer :subscribed_thread_ids
    add_method_tracer :upvoted_ids
    add_method_tracer :downvoted_ids
    add_method_tracer :subscribe
    add_method_tracer :mark_as_read
  rescue LoadError
    logger.warn "NewRelic agent library not installed"
  end

end

class ReadState
  include Mongoid::Document
  field :course_id, type: String
  field :last_read_times, type: Hash, default: {}
  embedded_in :user

  validates_presence_of :course_id
  validates_uniqueness_of :course_id

  def to_hash
    to_json
  end
end
