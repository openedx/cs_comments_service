class User
  include Mongoid::Document
  include Mongo::Voter

  key :external_id, type: String, index: true
  
  has_many :comments
  has_many :comment_threads, inverse_of: :author
  has_many :activities, class_name: "Notification", inverse_of: :actor
  has_and_belongs_to_many :notifications, inverse_of: :receivers

  validates_presence_of :external_id
  validates_uniqueness_of :external_id

  def subscriptions_as_source
    Subscription.where(source_id: id.to_s, source_type: self.class.to_s)
  end

  def subscriptions_as_subscriber
    Subscription.where(subscriber_id: id.to_s)
  end

  def subscribed_thread_ids
    subscriptions_as_subscriber.where(source_type: "CommentThread").map(&:source_id)
  end

  def subscribed_commentable_ids
    subscriptions_as_subscriber.where(source_type: "Commentable").map(&:source_id)
  end

  def subscribed_user_ids
    subscriptions_as_subscriber.where(source_type: "User").map(&:source_id)
  end

  def to_hash(params={})
    hash = as_document.slice(*%w[_id external_id])
    if params[:complete]
      hash = hash.merge("subscribed_thread_ids" => subscribed_thread_ids,
                        "subscribed_commentable_ids" => subscribed_commentable_ids,
                        "subscribed_user_ids" => subscribed_user_ids,
                        "follower_ids" => subscriptions_as_source.map(&:subscriber_id),
                        "upvoted_ids" => upvoted_ids,
                        "downvoted_ids" => downvoted_ids)
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
      nil
    else
      Subscription.find_or_create_by(subscriber_id: self._id.to_s, source_id: source._id.to_s, source_type: source.class.to_s)
    end
  end

  def unsubscribe(source)
    subscription = Subscription.where(subscriber_id: self._id.to_s, source_id: source._id.to_s, source_type: source.class.to_s).first
    subscription.destroy
    subscription
  end

end
