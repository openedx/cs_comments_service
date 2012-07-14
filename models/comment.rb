require 'mongoid'

class Comment
  include Mongoid::Document
  include Mongoid::Tree
  include Mongo::Voteable
  include Mongoid::Timestamps
  
  voteable self, :up => +1, :down => -1

  field :body, type: String
  field :course_id, type: String
  field :endorsed, type: Boolean, default: false

  belongs_to :author, class_name: "User", index: true
  belongs_to :comment_thread, index: true

  attr_accessible :body, :course_id

  validates_presence_of :body
  validates_presence_of :course_id
  validates_presence_of :author

  before_destroy :delete_descendants
  #after_create :create_feeds

end
