class CommentThread
  include Mongoid::Document
  field :title, type: String
  field :body, type: String
  field :course_id, type: String
  field :commentable_id, type: String
  field :commentable_type, type: String
  belongs_to :author, class_name: "User"
  has_many :comments
end
