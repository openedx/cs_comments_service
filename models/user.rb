class User
  include Mongoid::Document
  include Mongo::Voter

  field :_id, type: String, default: -> { external_id }
  field :external_id, type: String
  field :username, type: String
  field :email, type: String
  field :default_sort_key, type: String, default: "date"

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

  index external_id: 1

  def subscriptions_as_source
    Subscription.where(source_id: id.to_s, source_type: self.class.to_s)
  end

  def subscriptions_as_subscriber
    Subscription.where(subscriber_id: id.to_s)
  end

  def subscribed_thread_ids
    subscriptions_as_subscriber.where(source_type: "CommentThread").only(:source_id).map(&:source_id)
  end

  def subscribed_commentable_ids
    subscriptions_as_subscriber.where(source_type: "Commentable").only(:source_id).map(&:source_id)
  end

  def subscribed_user_ids
    subscriptions_as_subscriber.where(source_type: "User").only(:source_id).map(&:source_id)
  end

  def subscribed_threads
    CommentThread.where(:id.in => subscribed_thread_ids)
  end

  def subscribed_commentables
    Commentable.where(:id.in => subscribed_commentable_ids).only(:id).map(&:id)
  end

  def subscribed_users
    subscribed_user_ids.map {|id| User.find(id)}
  end

  def to_hash(params={})
    hash = as_document.slice(*%w[username external_id])
    if params[:complete]
      hash = hash.merge("subscribed_thread_ids" => subscribed_thread_ids,
                        "subscribed_commentable_ids" => subscribed_commentable_ids,
                        "subscribed_user_ids" => subscribed_user_ids,
                        "follower_ids" => subscriptions_as_source.only(:subscriber_id).map(&:subscriber_id),
                        "id" => id,
                        "upvoted_ids" => upvoted_ids,
                        "downvoted_ids" => downvoted_ids,
                        "default_sort_key" => default_sort_key)
    end
    if params[:course_id]
      hash = hash.merge("threads_count" => comment_threads.where(course_id: params[:course_id]).count,
                        "comments_count" => comments.where(course_id: params[:course_id]).count,
                       )
    end
    hash
  end

  def upvoted_ids
    Comment.up_voted_by(self).map(&:id) + CommentThread.up_voted_by(self).map(&:id)
  end

  def downvoted_ids
    Comment.down_voted_by(self).map(&:id) + CommentThread.down_voted_by(self).map(&:id)
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

end
