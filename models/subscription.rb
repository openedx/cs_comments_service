class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscriber_id, type: String
  field :source_id, type: String
  field :source_type, type: String
  
  index [[:subscriber_id, Mongo::ASCENDING], [:source_id, Mongo::ASCENDING], [:source_type, Mongo::ASCENDING]]

  def to_hash
    as_document.slice(*%w[subscriber_id source_id source_type])
  end

  def subscriber
    User.find(subscriber_id)
  end

  def source
    source_type.constantize.find(source_id)
  end

end
