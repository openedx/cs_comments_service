class Commentable

  attr_accessor :id
  alias_attribute :_id, :id
  
  class << self; alias_method :find, :new; end

  def initialize(id)
    self.id = id
  end

  def comment_threads
    CommentThread.where(commentable_id: id)
  end

  def subscriptions
    Subscription.where(source_id: id.to_s, source_type: self.class.to_s)
  end

  def subscribers
    subscriptions.map(&:subscriber)
  end

end
