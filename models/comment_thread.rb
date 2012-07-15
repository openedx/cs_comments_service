class CommentThread
  include Mongoid::Document
  include Mongo::Voteable
  include Mongoid::Timestamps

  voteable self, :up => +1, :down => -1

  field :title, type: String
  field :body, type: String
  field :course_id, type: String, index: true

  belongs_to :author, class_name: "User", inverse_of: :comment_threads, index: true
  belongs_to :commentable, index: true
  has_many :comments, dependent: :destroy # Use destroy to envoke callback on the top-level comments
  has_and_belongs_to_many :watchers, class_name: "User", inverse_of: :watched_comment_threads

  attr_accessible :title, :body, :course_id

  validates_presence_of :title
  validates_presence_of :body
  validates_presence_of :course_id # do we really need this?
  #validates_presence_of :author #allow anonymity?
  
  after_create :generate_feeds
  
  def to_hash(params={})
    doc = as_document.slice(*%w[title body course_id _id]).
                      merge("user_id" => author.external_id).
                      merge("votes" => votes.slice(*%w[count up_count down_count point]))
    if params[:recursive]
      doc = doc.merge("children" => comments.map{|c| c.to_hash(recursive: true)})
    end
    doc
  end

  def generate_feeds
    feed = Feed.new(
      feed_type: "post_topic",
      info: {
        commentable_id: commentable.id,
        commentable_type: commentable.type,
        comment_thread_id: comment_thread.id,
        comment_thread_title: comment_thread.title,
      },
    )
    feed.actor = author
    feed.target = self
    feed.subscribers << commentable.watchers
    feed.subscribers << author.followers
    feed.save!
  end

  handle_asynchronously :generate_feeds
end
