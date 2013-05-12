require_relative 'content'

class Comment < Content

  include Mongoid::Tree
  include Mongo::Voteable
  include Mongoid::Timestamps
  include Mongoid::MagicCounterCache
  
  voteable self, :up => +1, :down => -1

  field :course_id, type: String
  field :body, type: String
  field :endorsed, type: Boolean, default: false
  field :anonymous, type: Boolean, default: false
  field :anonymous_to_peers, type: Boolean, default: false
  field :at_position_list, type: Array, default: []

  index({author_id: 1, course_id: 1})

  belongs_to :comment_thread, index: true
  belongs_to :author, class_name: "User", index: true

  attr_accessible :body, :course_id, :anonymous, :anonymous_to_peers, :endorsed

  validates_presence_of :comment_thread, autosave: false
  validates_presence_of :body
  validates_presence_of :course_id
  validates_presence_of :author, autosave: false

  counter_cache :comment_thread

  before_destroy :delete_descendants # TODO async

  before_create :set_thread_last_activity_at
  before_update :set_thread_last_activity_at

  def self.hash_tree(nodes)
    nodes.map{|node, sub_nodes| node.to_hash.merge("children" => hash_tree(sub_nodes).compact)}
  end

  # This should really go somewhere else, but sticking it here for now. This is
  # used to flatten out the subtree fetched by calling self.subtree. This is
  # equivalent to calling descendants_and_self; however, calling
  # descendants_and_self and subtree both is very inefficient. It's cheaper to
  # just flatten out the subtree, and simpler than duplicating the code that
  # actually creates the subtree.
  def self.flatten_subtree(x)
    if x.is_a? Array
      x.flatten.map{|y| self.flatten_subtree(y)}
    elsif x.is_a? Hash
      x.to_a.map{|y| self.flatten_subtree(y)}.flatten
    else
      x
    end
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
      subtree_hash = subtree(sort: sort_by_parent_and_time)

      # Flatten out the subtree and fetch all users in bulk; makes getting the
      # usernames faster. Should probably denormalize usernames.
      flattened_subtree = Comment.flatten_subtree(subtree_hash)
      User.only(:username).find(flattened_subtree.map{|x| x.author_id})

      self.class.hash_tree(subtree_hash).first
    else
      as_document.slice(*%w[body course_id endorsed anonymous anonymous_to_peers created_at updated_at at_position_list])
                 .merge("id" => _id)
                 .merge("user_id" => author_id)
                 .merge("username" => author.username)
                 .merge("depth" => depth)
                 .merge("closed" => comment_thread.closed)
                 .merge("thread_id" => comment_thread_id)
                 .merge("commentable_id" => comment_thread.commentable_id)
                 .merge("votes" => votes.slice(*%w[count up_count down_count point]))
                 .merge("type" => "comment")
    end
  end

private

  def set_thread_last_activity_at
    self.comment_thread.update_attributes!(last_activity_at: Time.now.utc)
  end

end
