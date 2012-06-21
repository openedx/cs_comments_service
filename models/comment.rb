require 'active_record'
require 'ancestry'

class Comment < ActiveRecord::Base

  attr_accessible :body, :title, :user_id, :course_id, :comment_thread_id

  has_ancestry

  has_many :votes

  belongs_to :comment_thread

  validates_presence_of :body, :unless => :is_root?
  validates_presence_of :user_id, :unless => :is_root?
  validates_presence_of :course_id, :unless => :is_root?
  validates_presence_of :comment_thread_id

  def self.hash_tree(nodes)
    nodes.map {|node, sub_nodes| node.to_hash.merge(:children => hash_tree(sub_nodes).compact)}
  end

  def to_hash_tree
    self.class.hash_tree(self.subtree.arrange(:order => "updated_at DESC"))
  end

  def to_hash
    attributes.merge(:votes => {:up => Vote.comment_id(id).up.count, :down => Vote.comment_id(id).down.count})
  end

  def to_json
    to_hash.to_json
  end

end
