class Comment
  include Mongoid::Document
  include Mongoid::Tree
  include Mongo::Voteable
  include Mongoid::Timestamps
  
  voteable self, :up => +1, :down => -1

  field :body, type: String
  field :course_id, type: String
  field :endorsed, type: Boolean, default: false

  belongs_to :author, class_name: "User", index: true, autosave: true
  belongs_to :comment_thread, index: true, autosave: true

  attr_accessible :body, :course_id, :endorsed

  validates_presence_of :body
  validates_presence_of :course_id # do we really need this?
  #validates_presence_of :author # allow anonymity?

  before_destroy :delete_descendants # TODO async
  after_create :generate_feeds
  
  def self.hash_tree(nodes)
    nodes.map{|node, sub_nodes| node.to_hash.merge("children" => hash_tree(sub_nodes).compact)}
  end

  def get_comment_thread
    if comment_thread
      comment_thread
    else
      root.comment_thread
    end
  end

  def to_hash(params={})
    sort_by_parent_and_time = Proc.new do |x, y|
      arr_cmp = x.parent_ids <=> y.parent_ids
      if arr_cmp != 0
        arr_cmp
      else
        x.created_at <=> y.created_at
      end
    end
    if params[:recursive]
      self.class.hash_tree(subtree(sort: sort_by_parent_and_time)).first
    else
      as_document.slice(*%w[body course_id endorsed _id]).
                  merge("user_id" => author.id).
                  merge("votes" => votes.slice(*%w[count up_count down_count point]))
    end
  end

  def generate_feeds
    feed = Feed.new(
      feed_type: "post_reply",
      info: {
        comment_thread_id: get_comment_thread.id,
        comment_thread_title: get_comment_thread.title,
        comment_id: id,
      },
    )
    feed.actor = author
    feed.target = self
    feed.subscribers << (get_comment_thread.watchers + author.followers).uniq_by(&:id).delete(author) # doesn't send notification to author
    feed.save!
  end

  handle_asynchronously :generate_feeds

end
