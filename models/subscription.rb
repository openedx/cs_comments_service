class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :subscriber, class_name: "User", autosave: true, index: true
  belongs_to :source, polymorphic: true, autosave: true, index: true
  
  index [[:subscriber_id, Mongo::ASCENDING], [:source_id, Mongo::ASCENDING], [:source_type, Mongo::ASCENDING]]

  def to_hash
    as_document
  end

end
