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
  field :at_position_list, type: Array, default: []

  belongs_to :comment_thread, index: true
  belongs_to :author, class_name: "User", index: true

  attr_accessible :body, :course_id, :anonymous, :endorsed

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
      as_document.slice(*%w[body course_id endorsed anonymous created_at updated_at at_position_list])
                  .merge("id" => _id)
                  .merge("user_id" => author.id)
                  .merge("username" => author.username)
                  .merge("depth" => depth)
                  .merge("thread_id" => comment_thread.id)
                  .merge("votes" => votes.slice(*%w[count up_count down_count point]))
    end
  end

private

  def set_thread_last_activity_at
    self.comment_thread.update_attributes!(last_activity_at: Time.now.utc)
  end

end
