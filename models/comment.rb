class Comment
  include Mongoid::Document
  include Mongoid::Tree
  include Mongo::Voteable
  field :ancestry, type:String
  field :body, type: String
  field :user_id, type: String
  field :course_id, type: String
  belongs_to :comment_thread
end
