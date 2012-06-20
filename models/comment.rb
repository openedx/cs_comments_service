require 'active_record'
require 'ancestry'

class Comment < ActiveRecord::Base

  attr_accessible :body, :title, :user_id, :course_id, :comment_thread_id

  has_ancestry

  has_many :votes

  belongs_to :comment_thread

  def self.hash_tree(nodes)
    nodes.map do |node, sub_nodes|
      {
        :id => node.id,
        :body => node.body, 
        :title => node.title, 
        :user_id => node.user_id, 
        :course_id => node.course_id,
        :created_at => node.created_at,
        :updated_at => node.updated_at,
        :comment_thread_id => node.comment_thread_id,
        :children => hash_tree(sub_nodes).compact,
        :votes => {:up => Vote.comment_id(node.id).up.count, :down => Vote.comment_id(node.id).down.count},
      }
    end
  end

  def to_hash_tree
    self.class.hash_tree(self.subtree.arrange)
  end

end
