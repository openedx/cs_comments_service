require 'new_relic/agent/method_tracer'

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
  validates_presence_of :email
  validates_uniqueness_of :external_id
  validates_uniqueness_of :username
  validates_uniqueness_of :email

  index( {external_id: 1}, {unique: true, background: true} )

  def subscriptions_as_source
    Subscription.where(source_id: id.to_s, source_type: self.class.to_s)
  end

  def subscribed_thread_ids
    Subscription.where(subscriber_id: id.to_s, source_type: "CommentThread").only(:source_id).map(&:source_id)
  end

  def subscribed_threads
    CommentThread.where(:id.in => subscribed_thread_ids)
  end

  def to_hash(params={})
    hash = as_document.slice(*%w[username external_id])
    if params[:complete]
      hash = hash.merge("subscribed_thread_ids" => subscribed_thread_ids,
                        "subscribed_commentable_ids" => [], # not used by comment client.  To be removed once removed from comment client.
                        "subscribed_user_ids" => [], # ditto.
                        "follower_ids" => [], # ditto.
                        "id" => id,
                        "upvoted_ids" => upvoted_ids,
                        "downvoted_ids" => downvoted_ids,
                        "default_sort_key" => default_sort_key
                       )
    end
    if params[:course_id]
      self.class.trace_execution_scoped(['Custom/User.to_hash/count_comments_and_threads']) do
        hash = hash.merge("threads_count" => CommentThread.where(author_id: id,course_id: params[:course_id], anonymous: false, anonymous_to_peers: false).count,
                          "comments_count" => Comment.where(author_id: id, course_id: params[:course_id], anonymous: false, anonymous_to_peers: false).count
                         )
      end
    end
    hash
  end

  def upvoted_ids
    Content.up_voted_by(self).map(&:id)
  end

  def downvoted_ids
    Content.down_voted_by(self).map(&:id)
  end

  def followers
    subscriptions_as_source.map(&:subscriber)
  end

  def subscribe(source)
    if source._id == self._id and source.class == self.class
      raise ArgumentError, "Cannot follow oneself"
    else
      Subscription.find_or_create_by(subscriber_id: self._id.to_s, source_id: source._id.to_s, source_type: source.class.to_s)
    end
  end

  def unsubscribe(source)
    subscription = Subscription.where(subscriber_id: self._id.to_s, source_id: source._id.to_s, source_type: source.class.to_s).first
    subscription.destroy if subscription
    subscription
  end

  def mark_as_read(thread)
    read_state = read_states.find_or_create_by(course_id: thread.course_id)
    read_state.last_read_times[thread.id.to_s] = Time.now.utc
    read_state.save
  end

  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :to_hash
  add_method_tracer :subscribed_thread_ids
  add_method_tracer :upvoted_ids
  add_method_tracer :downvoted_ids

end

class ReadState
  include Mongoid::Document
  field :course_id, type: String
  field :last_read_times, type: Hash, default: {}
  embedded_in :user

  validates :course_id, uniqueness: true, presence: true
  
  def to_hash
    to_json
  end
end
