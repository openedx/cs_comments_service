class Activity
  include Mongoid::Document
  include Mongoid::Timestamps

  field :anonymous, type: Boolean
  field :activity_type, type: String
  field :happend_at, type: Time

  belongs_to :actor, class_name: "User", inverse_of: :activities, index: true, autosave: true
  belongs_to :target, inverse_of: :activities, polymorphic: true, index: true, autosave: true

  validates_presence_of :actor
  #validates_presence_of :target


end
