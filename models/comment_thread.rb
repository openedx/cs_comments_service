require 'active_record'

class CommentThread < ActiveRecord::Base
  
  has_one :super_comment, :class_name => "Comment", :dependent => :destroy

  # Ensures that each thread is associated with a commentable object
  validates_presence_of :commentable_type, :commentable_id

  # Ensures that there is only one thread for each commentable object
  validates_uniqueness_of :commentable_id, :scope => :commentable_type

  # Helper class method to create a new thread with the corresponding super comment
  #def self.find_or_build(commentable_type, commentable_id)
  #  comment_thread = CommentThread.find_or_create_by_commentable_type_and_commentable

  # Create a super comment which does not hold anything itself, but points to all comments of the thread
  after_create :create_super_comment
  
  def create_super_comment
    comment = Comment.create! :comment_thread_id => self.id
  end

  def root_comments
    super_comment.children
  end

  def comments
    super_comment.descendants
  end

  def json_comments
    super_comment.to_hash_tree.first[:children].to_json
  end

end
