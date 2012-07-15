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
  validates_presence_of :course_id # do we really need this?
  #validates_presence_of :author # allow anonymity?

  before_destroy :delete_descendants
  #after_create :create_feeds
  
  def self.hash_tree(nodes)
    nodes.map{|node, sub_nodes| node.to_hash.merge("children" => hash_tree(sub_nodes).compact)}
  end

  def to_hash(params={})
    if params[:recursive]
      self.class.hash_tree(subtree(order_by: [[:parent_ids, :asc], [:created_at, :asc]]))
    else
      as_document.slice(*%w[body course_id endorsed _id]).
                  merge("user_id" => author.external_id).
                  merge("votes" => votes.slice(*%w[count up_count down_count point]))
    end
  end

end
