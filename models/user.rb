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

  def to_hash(params={})
    as_document.slice(*%w[_id external_id])
  end

  def followers
    subscriptions_as_source.map(&:subscriber)
  end

  def subscribe(source)
    Subscription.find_or_create_by(subscriber_id: self._id.to_s, source_id: source._id.to_s, source_type: source.class.to_s)
  end

  def unsubscribe(source)
    subscription = Subscription.where(subscriber_id: self._id.to_s, source_id: source._id.to_s, source_type: source.class.to_s).first
    subscription.destroy
    subscription
  end

end
