class Commentable

  attr_accessor :id, :_type
  alias_attribute :_id, :id
  
  class << self; alias_method :find, :new; end

  def initialize(id)
    self.id = id
    self._type = self.class.to_s
  end

  def self.where(params={})
    params[:id] ? [self.new(params[:id])] : self
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
