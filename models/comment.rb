require_relative 'content'

class Comment < Content

  include Mongoid::Tree
  include Mongoid::Timestamps
  include Mongoid::MagicCounterCache
  
  voteable self, :up => +1, :down => -1

  field :course_id, type: String
  field :body, type: String
  field :endorsed, type: Boolean, default: false
  field :endorsement, type: Hash
  field :anonymous, type: Boolean, default: false
  field :anonymous_to_peers, type: Boolean, default: false
  field :at_position_list, type: Array, default: []

  index({author_id: 1, course_id: 1})
  index({_type: 1, comment_thread_id: 1, author_id: 1, updated_at: 1})

  field :sk, type: String, default: nil
  before_save :set_sk  
  def set_sk()
    # this attribute is explicitly write-once
    if self.sk.nil?
      self.sk = (self.parent_ids.dup << self.id).join("-") 
    end
  end

  include Tire::Model::Search
  include Tire::Model::Callbacks

  index_name Content::ES_INDEX_NAME

  mapping do
    indexes :body, type: :string, analyzer: :english, stored: true, term_vector: :with_positions_offsets
    indexes :course_id, type: :string, index: :not_analyzed, included_in_all: false
    indexes :comment_thread_id, type: :string, index: :not_analyzed, included_in_all: false, as: 'comment_thread_id'
    indexes :commentable_id, type: :string, index: :not_analyzed, included_in_all: false, as: 'commentable_id'
    indexes :group_id, type: :string, index: :not_analyzed, included_in_all: false, as: 'group_id'
    indexes :created_at, type: :date, included_in_all: false
    indexes :updated_at, type: :date, included_in_all: false
  end
  

  belongs_to :comment_thread, index: true
  belongs_to :author, class_name: "User", index: true

  attr_accessible :body, :course_id, :anonymous, :anonymous_to_peers, :endorsed, :endorsement

  validates_presence_of :comment_thread, autosave: false
  validates_presence_of :body
  validates_presence_of :course_id
  validates_presence_of :author, autosave: false

  counter_cache :comment_thread

  before_destroy :destroy_children # TODO async

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
      # TODO: remove and reuse the new hierarchical sort keys if possible
      subtree_hash = subtree(sort: sort_by_parent_and_time)
      self.class.hash_tree(subtree_hash).first
    else
      as_document.slice(*%w[body course_id endorsed endorsement anonymous anonymous_to_peers created_at updated_at at_position_list])
                 .merge("id" => _id)
                 .merge("user_id" => author_id)
                 .merge("username" => author_username) 
                 .merge("depth" => depth)
                 .merge("closed" => comment_thread.nil? ? false : comment_thread.closed) # ditto
                 .merge("thread_id" => comment_thread_id)
                 .merge("commentable_id" => comment_thread.nil? ? nil : comment_thread.commentable_id) # ditto
                 .merge("votes" => votes.slice(*%w[count up_count down_count point]))
                 .merge("abuse_flaggers" => abuse_flaggers)
                 .merge("type" => "comment")
    end
  end
  
  def commentable_id
    #we need this to have a universal access point for the flag rake task
    if self.comment_thread_id
      t = CommentThread.find self.comment_thread_id
      if t
        t.commentable_id
      end
    end
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  def group_id
    if self.comment_thread_id
      t = CommentThread.find self.comment_thread_id
      if t
        t.group_id
      end
    end
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  def self.by_date_range_and_thread_ids from_when, to_when, thread_ids
     #return all content between from_when and to_when

     self.where(:created_at.gte => (from_when)).where(:created_at.lte => (to_when)).
       where(:comment_thread_id.in => thread_ids)
  end
  
private

  def set_thread_last_activity_at
    self.comment_thread.update_attributes!(last_activity_at: Time.now.utc)
  end

end
