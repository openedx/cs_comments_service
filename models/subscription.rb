class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :subscriber, class_name: "User", autosave: true
  belongs_to :source, polymorphic: true, autosave: true

  index [[:subscriber_id, Mongo::ASCENDING], [:source_id, Mongo::ASCENDING], [:source_type, Mongo::ASCENDING]]
  index [[:source_id, Mongo::ASCENDING], [:source_type, Mongo::ASCENDING]]
  index :subscriber_id

  def to_hash
    as_document
  end

end
