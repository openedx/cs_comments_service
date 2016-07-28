require_relative 'constants'

class Notification
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::MassAssignmentSecurity

  field :notification_type, type: String
  field :info, type: Hash

  attr_accessible :notification_type, :info

  validates_presence_of :notification_type
  validates_presence_of :info

  has_and_belongs_to_many :receivers, class_name: "User", inverse_of: :notifications, autosave: true

  def to_hash(params={})
    as_document
      .slice(NOTIFICATION_TYPE, INFO, ACTOR_ID, TARGET_ID)
      .merge!("id" => _id)
  end
end
