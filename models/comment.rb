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

  def subtree
    arrange(descendants.order_by([[:parent_ids, :asc], [:created_at, :asc]]))
  end

  def to_hash(params={})
    doc = as_document.slice(*%w[body course_id endorsed _id]).
                      merge("user_id" => author.external_id).
                      merge("votes" => votes.slice(*%w[count up_count down_count point]))
    if params[:recursive]
      doc = doc.merge("children" => self.class.hash_tree(subtree))
    end
    doc
  end

private
  # adopted and modified from https://github.com/stefankroes/ancestry/blob/master/lib/ancestry/class_methods.rb 
  def arrange(nodes)
    # Get all nodes ordered by ancestry and start sorting them into an empty hash
    nodes.inject(ActiveSupport::OrderedHash.new) do |arranged_nodes, node|
      # Find the insertion point for that node by going through its ancestors
      node.parent_ids.inject(arranged_nodes) do |insertion_point, parent_id|
        insertion_point.each do |parent, children|
          # Change the insertion point to children if node is a descendant of this parent
          insertion_point = children if parent_id == parent._id
        end
        insertion_point
      end[node] = ActiveSupport::OrderedHash.new
      arranged_nodes
    end
  end

end
