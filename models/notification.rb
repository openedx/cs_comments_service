class Notification
  include Mongoid::Document
  include Mongoid::Timestamps

  field :notification_type, type: String
  field :info, type: Hash

  attr_accessible :notification_type, :info

  validates_presence_of :notification_type
  validates_presence_of :info

  has_and_belongs_to_many :receivers, class_name: "User", inverse_of: :notifications, autosave: true

  def to_hash(params={})
    as_document.slice(*%w[notification_type info actor_id target_id]).merge("id" => _id)
  end
end
