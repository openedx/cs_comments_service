class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscriber_id, type: String
  field :source_id, type: String
  field :source_type, type: String
  
  index({subscriber_id: 1, source_id: 1, source_type: 1})
  index({subscriber_id: 1, source_type: 1})
  index({subscriber_id: 1})
  index({source_id: 1, source_type: 1}, {background: true})

  def to_hash
    as_document.slice(*%w[subscriber_id source_id source_type]).merge("id" => _id)
  end

  def subscriber
    User.find(subscriber_id)
  end

  def source
    source_type.constantize.find(source_id)
  end

end
