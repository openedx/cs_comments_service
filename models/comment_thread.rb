require_relative 'content'

class CommentThread < Content

  include Mongo::Voteable
  include Mongoid::Timestamps
  include Mongoid::TaggableWithContext
  include Mongoid::TaggableWithContext::AggregationStrategy::RealTime

  taggable separator: ',', default: []

  voteable self, :up => +1, :down => -1

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

  index({author_id: 1, course_id: 1})

  include Tire::Model::Search
  include Tire::Model::Callbacks

  mapping do
    indexes :title, type: :string, analyzer: :snowball, boost: 5.0, stored: true, term_vector: :with_positions_offsets
    indexes :body, type: :string, analyzer: :snowball, stored: true, term_vector: :with_positions_offsets
    indexes :tags_in_text, type: :string, as: 'tags_array', index: :analyzed
    indexes :tags_array, type: :string, as: 'tags_array', index: :not_analyzed, included_in_all: false
    indexes :created_at, type: :date, included_in_all: false
    indexes :updated_at, type: :date, included_in_all: false
    indexes :last_activity_at, type: :date, included_in_all: false

    indexes :comment_count, type: :integer, included_in_all: false
    indexes :votes_point, type: :integer, as: 'votes_point', included_in_all: false

    indexes :course_id, type: :string, index: :not_analyzed, included_in_all: false
    indexes :commentable_id, type: :string, index: :not_analyzed, included_in_all: false
    indexes :author_id, type: :string, as: 'author_id', index: :not_analyzed, included_in_all: false
    indexes :group_id, type: :integer, as: 'group_id', index: :not_analyzed, included_in_all: false
    #indexes :pinned, type: :boolean, as: 'pinned', index: :not_analyzed, included_in_all: false
  end

  belongs_to :author, class_name: "User", inverse_of: :comment_threads, index: true#, autosave: true
  has_many :comments, dependent: :destroy#, autosave: true# Use destroy to envoke callback on the top-level comments TODO async
  has_many :activities, autosave: true

  attr_accessible :title, :body, :course_id, :commentable_id, :anonymous, :anonymous_to_peers, :closed

  validates_presence_of :title
  validates_presence_of :body
  validates_presence_of :course_id # do we really need this?
  validates_presence_of :commentable_id
  validates_presence_of :author, autosave: false

  validate :tag_names_valid
  validate :tag_names_unique

  before_create :set_last_activity_at
  before_update :set_last_activity_at, :unless => lambda { closed_changed? }

  before_destroy :destroy_subscriptions

  scope :active_since, ->(from_time) { where(:last_activity_at => {:$gte => from_time}) }

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

  def self.search_result_to_hash(result, params={})

    comment_thread = self.find(result.id)
    highlight = result.highlight || {}

    highlighted_body = (highlight[:body] || []).first || comment_thread.body
    highlighted_title = (highlight[:title] || []).first || comment_thread.title
    comment_thread.to_hash(params).merge(highlighted_body: highlighted_body, highlighted_title: highlighted_title)
  end

  def self.perform_search(params, options={})
    page = [1, options[:page] || 1].max
    per_page = options[:per_page] || 20
    sort_key = options[:sort_key]
    sort_order = options[:sort_order]
    if CommentService.config[:cache_enabled]
      memcached_key = "threads_search_#{params.merge(options).hash}"
      results = Sinatra::Application.cache.get(memcached_key)
      if results
        return results
      end
    end
    search = Tire::Search::Search.new 'comment_threads'
    search.query {|query| query.text :_all, params["text"]} if params["text"]
    search.highlight({title: { number_of_fragments: 0 } } , {body: { number_of_fragments: 0 } }, options: { tag: "<highlight>" })
    search.filter(:bool, :must => params["tags"].split(/,/).map{ |tag| { :term => { :tags_array => tag } } }) if params["tags"]
    search.filter(:term, commentable_id: params["commentable_id"]) if params["commentable_id"]
    search.filter(:terms, commentable_id: params["commentable_ids"]) if params["commentable_ids"]
    search.filter(:term, course_id: params["course_id"]) if params["course_id"]
    
    if params["group_id"]
      
      search.filter :or, [
        {:not => {:exists => {:field => :group_id}}},
          {:term => {:group_id => params["group_id"]}}

        ]
    end
    
    search.sort {|sort| sort.by sort_key, sort_order} if sort_key && sort_order #TODO should have search option 'auto sort or sth'

    search.size per_page
    search.from per_page * (page - 1)
    
    results = search.results
    
    if CommentService.config[:cache_enabled]
      Sinatra::Application.cache.set(memcached_key, results, CommentService.config[:cache_timeout][:threads_search].to_i)
    end
    results
  end

  def activity_since(from_time=nil)
    if from_time
      activities.where(:created_at => {:$gte => from_time})
    else
      activities
    end
  end

  def activity_today; activity_since(Date.today.to_time); end

  def activity_this_week; activity_since(Date.today.to_time - 1.weeks); end

  def activity_this_month; activity_since(Date.today.to_time - 1.months); end

  def activity_overall; activity_since(nil); end

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
    doc = as_document.slice(*%w[title body course_id anonymous anonymous_to_peers commentable_id created_at updated_at at_position_list closed])
                     .merge("id" => _id, "user_id" => author_id,
                            "username" => author.username,
                            "votes" => votes.slice(*%w[count up_count down_count point]),
                            "tags" => tags_array,
                            "type" => "thread",
                            "group_id" => group_id,
                            "pinned" => pinned,
                            "endorsed" => endorsed?)

    if params[:recursive]
      doc = doc.merge("children" => root_comments.map{|c| c.to_hash(recursive: true)})
    end

    comments_count = comments.count

    if params[:user_id]
      user = User.find_or_create_by(external_id: params[:user_id])
      read_state = user.read_states.where(course_id: self.course_id).first
      last_read_time = read_state.last_read_times[self.id.to_s] if read_state
      # comments created by the user are excluded in the count
      # this is rather like a hack but it avoids the following situation:
      #   when you reply to a thread and while you are editing,
      #   other people also replied to the thread. Now if we simply
      #   update the last_read_time, then the other people's replies
      #   will not be included in the unread_count; if we leave it
      #   that way, then your own comment will be included in the
      #   unread count
      if last_read_time
        unread_count = self.comments.where(
            :updated_at => {:$gte => last_read_time},
            :author_id => {:$ne => params[:user_id]},
        ).count
        read = last_read_time >= self.updated_at
      else
        unread_count = self.comments.where(:author_id => {:$ne => params[:user_id]}).count
        read = false
      end
    else
      # If there's no user, say it's unread and all comments are unread
      unread_count = comments_count
      read = false
    end

    doc = doc.merge("unread_comments_count" => unread_count)
             .merge("read" => read)
             .merge("comments_count" => comments_count)

    doc

  end

  def self.tag_name_valid?(tag)
    !!(tag =~ RE_TAG)
  end

private

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

  def set_last_activity_at
    self.last_activity_at = Time.now.utc unless last_activity_at_changed?
  end

  def destroy_subscriptions
    subscriptions.delete_all
  end
end
