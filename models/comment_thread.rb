require_relative 'content'

class CommentThread < Content
  include Mongo::Voteable
  include Mongoid::Timestamps
  include Mongoid::Taggable

  voteable self, :up => +1, :down => -1

  field :comment_count, type: Integer, default: 0
  field :title, type: String
  field :body, type: String
  field :course_id, type: String
  field :commentable_id, type: String
  field :anonymous, type: Boolean, default: false

  include Sunspot::Mongoid
  searchable do
    text :title, boost: 5.0, stored: true, more_like_this: true
    text :body, stored: true, more_like_this: true

    time :created_at
    time :updated_at
    integer :comment_count
    integer :votes_point do
      votes_point
    end
    string :course_id
    string :commentable_id
    string :author_id
    string :tags, multiple: true do
      tags_array
    end
  end

  belongs_to :author, class_name: "User", inverse_of: :comment_threads, index: true
  has_many :comments, dependent: :destroy#, autosave: true# Use destroy to envoke callback on the top-level comments TODO async

  attr_accessible :title, :body, :course_id, :commentable_id, :anonymous

  validates_presence_of :title
  validates_presence_of :body
  validates_presence_of :course_id # do we really need this?
  validates_presence_of :commentable_id
  validates_presence_of :author, autosave: false

  validate :tag_names_valid
  validate :tag_names_unique

  after_create :generate_notifications

  def self.new_dumb_thread(options={})
    c = self.new
    c.title = options[:title] || "title"
    c.body = options[:body] || "body"
    c.commentable_id = options[:commentable_id] || "commentable_id"
    c.course_id = options[:course_id] || "course_id"
    c.author = options[:author] || User.first
    c.tags = options[:tags] || "test-tag-1, test-tag-2"
    c.save!
    c
  end

  def root_comments
    Comment.roots.where(comment_thread_id: self.id)
  end

  def commentable
    Commentable.find(commentable_id)
  end

  def subscriptions
    Subscription.where(source_id: id.to_s, source_type: self.class.to_s)
  end

  def subscribers
    subscriptions.map(&:subscriber)
  end

  def to_hash(params={})
    doc = as_document.slice(*%w[title body course_id anonymous commentable_id created_at updated_at])
                      .merge("id" => _id)
                      .merge("user_id" => author.id)
                      .merge("votes" => votes.slice(*%w[count up_count down_count point]))
                      .merge("tags" => tags_array)

    if params[:recursive]
      doc = doc.merge("children" => root_comments.map{|c| c.to_hash(recursive: true)})
    else
      doc = doc.merge("comments_count" => comments.count)
    end
    doc
  end

  def self.search_text(text, commentable_id=nil)
    self.solr_search do
      fulltext(text)
      if commentable_id
        with(:commentable_id, commentable_id)
      end
    end
  end

  def self.tag_name_valid?(tag)
    !!(tag =~ RE_TAG)
  end

private
  def generate_notifications
    if subscribers or (author.followers if not anonymous)
      notification = Notification.new(
        notification_type: "post_topic",
        info: {
          commentable_id: commentable_id,
          #commentable_type: commentable.commentable_type,
          thread_id: id,
          thread_title: title,
        },
      )
      notification.actor = author if not anonymous
      notification.target = self
      receivers = commentable.subscribers
      if not anonymous
        receivers = (receivers + author.followers).uniq_by(&:id)
      end
      receivers.delete(author)
      notification.receivers << receivers
      notification.save!
    end
  end

  RE_HEADCHAR = /[a-z0-9]/
  RE_ENDONLYCHAR = /\+/
  RE_ENDCHAR = /[a-z0-9\#]/
  RE_CHAR = /[a-z0-9\-\#\.]/
  RE_WORD = /#{RE_HEADCHAR}(((#{RE_CHAR})*(#{RE_ENDCHAR})+)?(#{RE_ENDONLYCHAR})*)?/
  RE_TAG = /^#{RE_WORD}( #{RE_WORD})*$/

  

  def tag_names_valid
    unless tags_array.all? {|tag| self.class.tag_name_valid? tag}
      errors.add :tag, "can consist of words, numbers, dashes and spaces only and cannot start with dash"
    end
  end

  def tag_names_unique
    unless tags_array.uniq.size == tags_array.size
      errors.add :tags, "must be unique"
    end
  end

  handle_asynchronously :generate_notifications
end
