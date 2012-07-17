class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :subscriber_id, type: String
  field :source_id, type: String
  field :source_type, type: String

  index [[:subscriber_id, Mongo::ASCENDING], [:source_id, Mongo::ASCENDING], [:source_type, Mongo::ASCENDING]]
  index [[:source_id, Mongo::ASCENDING], [:source_type, Mongo::ASCENDING]]
  index :subscriber_id

  def to_hash
    as_document
  end

end
