class CommentThread
  include Mongoid::Document
  include Mongo::Voteable
  include Mongoid::Timestamps

  voteable self, :up => +1, :down => -1

  field :title, type: String
  field :body, type: String
  field :course_id, type: String, index: true

  belongs_to :author, class_name: "User", inverse_of: :comment_threads, index: true, autosave: true
  belongs_to :commentable, index: true, autosave: true
  has_many :comments, dependent: :destroy, autosave: true# Use destroy to envoke callback on the top-level comments TODO async
  has_and_belongs_to_many :watchers, class_name: "User", inverse_of: :watched_comment_threads, autosave: true

  attr_accessible :title, :body, :course_id

  validates_presence_of :title
  validates_presence_of :body
  validates_presence_of :course_id # do we really need this?
  validates_presence_of :author if not CommentService.config["allow_anonymity"]

  after_create :handle_after_create
  
  def to_hash(params={})
    doc = as_document.slice(*%w[title body course_id _id]).
                      merge("user_id" => (author.id if author)).
                      merge("votes" => votes.slice(*%w[count up_count down_count point]))
    if params[:recursive]
      doc = doc.merge("children" => comments.map{|c| c.to_hash(recursive: true)})
    end
    doc
  end

private
  def generate_notifications
    if watchers or (author.followers if author)
      notification = Notification.new(
        notification_type: "post_topic",
        info: {
          commentable_id: commentable.commentable_id,
          commentable_type: commentable.commentable_type,
          thread_id: id,
          thread_title: title,
        },
      )
      notification.actor = author
      notification.target = self
      notification.receivers << (commentable.watchers + (author.followers if author).to_a).uniq_by(&:id)
      notification.receivers.delete(author) if not CommentService.config["send_notifications_to_author"] and author
      notification.save!
    end
  end

  def auto_watch_comment_thread
    if CommentService.config["auto_watch_comment_threads"] and author
      author.watch_comment_thread(self)
    end
  end

  def handle_after_create
    generate_notifications
    auto_watch_comment_thread
  end

  handle_asynchronously :handle_after_create
end
