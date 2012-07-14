class CommentThread
  include Mongoid::Document
  include Mongo::Voteable
  include Mongoid::Timestamps

  voteable self, :up => +1, :down => -1

  field :title, type: String
  field :body, type: String
  field :course_id, type: String, index: true
  field :commentable_id, type: String
  field :commentable_type, type: String

  belongs_to :author, class_name: "User", index: true
  has_many :comments, dependent: :destroy # Use destroy to envoke callback on the top-level comments

  attr_accessible :title, :body, :course_id, :commentable_id, :commentable_type

  validates_presence_of :title
  validates_presence_of :body
  validates_presence_of :course_id
  validates_presence_of :commentable_id
  validates_presence_of :commentable_type
  
  index [:commentable_type, :commentable_id]
  #after_create :create_feeds

end
