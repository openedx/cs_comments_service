require_relative 'content'

class Comment < Content
  include Mongoid::Tree
  include Mongo::Voteable
  include Mongoid::Timestamps
  
  voteable self, :up => +1, :down => -1

  field :body, type: String
  field :course_id, type: String
  field :endorsed, type: Boolean, default: false

  belongs_to :author, class_name: "User", index: true
  belongs_to :comment_thread, index: true

  attr_accessible :body, :course_id, :endorsed

  validates_presence_of :body
  validates_presence_of :course_id # do we really need this?
  validates_presence_of :comment_thread

  before_destroy :delete_descendants # TODO async
  after_create :generate_notifications
  
  def self.hash_tree(nodes)
    nodes.map{|node, sub_nodes| node.to_hash.merge("children" => hash_tree(sub_nodes).compact)}
  end

  def to_hash(params={})
    sort_by_parent_and_time = Proc.new do |x, y|
      arr_cmp = x.parent_ids.map(&:to_s) <=> y.parent_ids.map(&:to_s)
      if arr_cmp != 0
        arr_cmp
      else
        x.created_at <=> y.created_at
      end
    end
    if params[:recursive]
      self.class.hash_tree(subtree(sort: sort_by_parent_and_time)).first
    else
      as_document.slice(*%w[body course_id endorsed created_at updated_at]).
                  merge("id" => _id).
                  merge("user_id" => author.id).
                  merge("thread_id" => comment_thread.id).
                  merge("votes" => votes.slice(*%w[count up_count down_count point]))
    end
  end

private
  def generate_notifications
    if comment_thread.subscribers or (author.followers if author)
      notification = Notification.new(
        notification_type: "post_reply",
        info: {
          thread_id: comment_thread.id,
          thread_title: comment_thread.title,
          comment_id: id,
          commentable_id: comment_thread.commentable_id,
        },
      )
      notification.actor = author
      notification.target = self
      notification.receivers << (comment_thread.subscribers + author.followers).uniq_by(&:id)
      notification.receivers.delete(author)
      notification.save!
    end
  end

  handle_asynchronously :generate_notifications

end
