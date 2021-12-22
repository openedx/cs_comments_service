require 'logger'
require_relative 'concerns/searchable'
require_relative 'content'
require_relative 'constants'
require_relative 'edit_history'

logger = Logger.new(STDOUT)
logger.level = Logger::WARN


class CommentThread < Content
  include Mongoid::Timestamps
  include Mongoid::Attributes::Dynamic
  include ActiveModel::MassAssignmentSecurity
  include Elasticsearch::Model
  include Searchable
  extend Enumerize

  voteable self, :up => +1, :down => -1

  field :thread_type, type: String, default: :discussion
  enumerize :thread_type, in: [:question, :discussion]
  field :context, type: String, default: :course
  enumerize :context, in: [:course, :standalone]
  field :comment_count, type: Integer, default: 0
  field :title, type: String
  field :body, type: String
  field :course_id, type: String
  field :commentable_id, type: String
  field :anonymous, type: Boolean, default: false
  field :anonymous_to_peers, type: Boolean, default: false
  field :closed, type: Boolean, default: false
  field :at_position_list, type: Array, default: []
  field :last_activity_at, type: Time
  field :group_id, type: Integer
  field :pinned, type: Boolean
  field :retired_username, type: String, default: nil
  field :close_reason_code, type: String, default: nil # string code that represents why a thread was closed.

  index({ author_id: 1, course_id: 1 })

  index_name = "comment_thread"

  mapping dynamic: 'false' do
    indexes :title, type: :text, boost: 5.0, store: true, term_vector: :with_positions_offsets
    indexes :body, type: :text, store: true, term_vector: :with_positions_offsets
    indexes :created_at, type: :date
    indexes :updated_at, type: :date
    indexes :last_activity_at, type: :date
    indexes :comment_count, type: :integer
    indexes :votes_point, type: :integer
    indexes :context, type: :keyword
    indexes :course_id, type: :keyword
    indexes :commentable_id, type: :keyword
    indexes :author_id, type: :keyword
    indexes :group_id, type: :integer
    indexes :id, type: :keyword
    indexes :thread_id, type: :keyword
  end

  def as_indexed_json(options={})
    as_json(except: [:thread_id, :_id])
  end

  belongs_to :author, class_name: 'User', inverse_of: :comment_threads, index: true
  belongs_to :closed_by, class_name: 'User', inverse_of: :threads_closed, optional: true
  has_many :comments, dependent: :destroy # Use destroy to invoke callback on the top-level comments
  has_many :activities, autosave: true
  embeds_many :edit_history, cascade_callbacks: true

  attr_accessible :title, :body, :course_id, :commentable_id, :anonymous, :anonymous_to_peers, :closed,
                  :thread_type, :retired_username, :close_reason_code, :closed_by

  validates_presence_of :thread_type
  validates_presence_of :context
  validates_presence_of :title
  validates_presence_of :body
  validates_presence_of :course_id # do we really need this?
  validates_presence_of :commentable_id
  validates_presence_of :author, autosave: false

  before_create :set_last_activity_at
  after_update :clear_endorsements
  before_destroy :destroy_subscriptions

  scope :active_since, ->(from_time) { where(:last_activity_at => {:$gte => from_time}) }
  scope :standalone_context, ->() { where(:context => :standalone) }
  scope :course_context, ->() { where(:context => :course) }

  def activity_since(from_time=nil)
    if from_time
      activities.where(:created_at => {:$gte => from_time})
    else
      activities
    end
  end

  def activity_today
    activity_since(Date.today.to_time)
  end

  def activity_this_week
    activity_since(Date.today.to_time - 1.weeks)
  end

  def activity_this_month
    activity_since(Date.today.to_time - 1.months)
  end

  def activity_overall
    activity_since(nil)
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

  def endorsed?
    comments.where(endorsed: true).exists?
  end

  def to_hash(params={})
    as_document
      .slice(THREAD_TYPE, TITLE, BODY, COURSE_ID, ANONYMOUS, ANONYMOUS_TO_PEERS, COMMENTABLE_ID, CREATED_AT, UPDATED_AT, AT_POSITION_LIST, CLOSED, CONTEXT, LAST_ACTIVITY_AT, CLOSE_REASON_CODE)
      .merge!("id" => _id,
              "user_id" => author_id,
              "username" => author_username,
              "votes" => votes.slice(COUNT, UP_COUNT, DOWN_COUNT, POINT),
              "abuse_flaggers" => abuse_flaggers,
              "closed_by" => closed_by? ? closed_by.username : nil,
              "edit_history" => edit_history.map(&:to_hash),
              "tags" => [],
              "type" => THREAD,
              "group_id" => group_id,
              "pinned" => pinned?,
              "comments_count" => comment_count)
  end

  def comment_thread_id
    #so that we can use the comment thread id as a common attribute for flagging
    self.id
  end

  private

  def set_last_activity_at
    self.last_activity_at = Time.now.utc unless last_activity_at_changed?
  end

  def clear_endorsements
    if self.thread_type_changed?
      # We use 'set' instead of 'update_attributes' because the Comment model has a 'before_update' callback that sets
      # the last activity time on the thread. Therefore the callbacks would be mutually recursive and we end up with a
      # 'SystemStackError'. The 'set' method skips callbacks and therefore bypasses this issue.
      self.comments.each do |comment|
        comment.set(endorsed: false)
        comment.set(endorsement: nil)
      end
    end
  end

  def destroy_subscriptions
    subscriptions.delete_all
  end

  begin
    require 'new_relic/agent/method_tracer'
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer :to_hash
  rescue LoadError
    logger.warn "NewRelic agent library not installed"
  end
end
