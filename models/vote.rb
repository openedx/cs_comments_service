require 'active_record'

# Adapted from "Service-Oriented Design with Ruby and Rails"
class Vote < ActiveRecord::Base

  attr_accessible :value, :user_id, :comment_id
  
  belongs_to :comment

  validates_inclusion_of :value, :in => %w{up down}
  validates_uniqueness_of :user_id, :scope => :comment_id
  validates_presence_of :comment_id, :user_id

  scope :up, :conditions => ["value = ?", "up"]
  scope :down, :conditions => ["value = ?", "down"]
  scope :user_id, lambda {|user_id| {:conditions => ["user_id = ?", user_id]}}
  scope :comment_id, lambda {|comment_id| {:conditions => ["comment_id = ?", comment_id]}}

  def self.create_or_update(attributes)
    vote = Vote.find_by_comment_id_and_user_id(attributes[:comment_id], attributes[:user_id])
    if vote
      vote.value = attributes[:value]
      vote.save
      vote
    else
      Vote.create(attributes)
    end
  end
  
end
