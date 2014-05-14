# -*- coding: utf-8 -*-
require 'new_relic/agent/method_tracer'
require_relative 'content'

class CommentThread < Content

  include Mongoid::Timestamps

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
    indexes :title, type: :string, analyzer: :english, boost: 5.0, stored: true, term_vector: :with_positions_offsets
    indexes :body, type: :string, analyzer: :english, stored: true, term_vector: :with_positions_offsets
    indexes :created_at, type: :date, included_in_all: false
    indexes :updated_at, type: :date, included_in_all: false
    indexes :last_activity_at, type: :date, included_in_all: false

    indexes :comment_count, type: :integer, included_in_all: false
    indexes :votes_point, type: :integer, as: 'votes_point', included_in_all: false

    indexes :course_id, type: :string, index: :not_analyzed, included_in_all: false
    indexes :commentable_id, type: :string, index: :not_analyzed, included_in_all: false
    indexes :author_id, type: :string, as: 'author_id', index: :not_analyzed, included_in_all: false
    indexes :group_id, type: :integer, as: 'group_id', index: :not_analyzed, included_in_all: false
    indexes :id,         :index    => :not_analyzed
    indexes :thread_id, :analyzer => :keyword, :as => "_id"
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
    c.save!
    c
  end

  def self.perform_search(params, options={})
    
    page = [1, options[:page] || 1].max
    per_page = options[:per_page] || 20
    sort_key = options[:sort_key]
    sort_order = options[:sort_order]
    

#GET /api/v1/search/threads?user_id=1&recursive=False&sort_key=date&│[2013-06-28 10:16:46,104][INFO ][plugins                  ] [Glamor] loaded [], sites []                  
#text=response&sort_order=desc&course_id=HarvardX%2FHLS1xD%2FCopyright&per_page=20&api_key=PUT_YOUR_API_KE│T1GYWxzZSZzb3J0X2tleT1kYXRlJnRleHQ9cmVzcG9uc2Umc29ydF9vcmRlcj1kZXNjJmNvdXJzZV9pZA==: initialized          
#Y_HERE&page=1

    #KChugh - Unfortunately, there's no algorithmically nice way to handle pagination with
    #stitching together Comments and CommentThreads, because there is no determinstic relationship
    #between the ordinality of comments and threads. 
    #the best solution is to find all of the thread ids for matching comment hits, and union them
    #with the comment thread query, however, Tire does not support ORing a query key with a term filter
    
    #so the 3rd best solution is to run two Tire searches (3 actually, one to query the comments, one to query the threads based on
    #thread ids and the original thread search) and merge the results, uniqifying the results in the process.
      
    #so first, find the comment threads associated with comments that hit the query
        
    search = Tire::Search::Search.new 'comment_threads'

    search.query {|query| query.match [:title, :body], params["text"]} if params["text"]
    search.highlight({title: { number_of_fragments: 0 } } , {body: { number_of_fragments: 0 } }, options: { tag: "<highlight>" })
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

    #again, b/c there is no relationship in ordinality, we cannot paginate if it's a text query
    results = search.results

    search = Tire::Search::Search.new 'comments'
    search.query {|query| query.match :body, params["text"]} if params["text"]
    search.filter(:term, course_id: params["course_id"]) if params["course_id"]
    search.size CommentService.config["max_deep_search_comment_count"].to_i

    #unforutnately, we cannot paginate here, b/c we don't know how the ordinality is totally
    #unrelated to that of threads

    c_results = comment_ids = comments = thread_ids = nil
    self.class.trace_execution_scoped(['Custom/perform_search/collect_comment_search_results']) do
      c_results = search.results
      comment_ids = c_results.collect{|c| c.id}.uniq
    end
    self.class.trace_execution_scoped(['Custom/perform_search/collect_comment_thread_ids']) do
      comments = Comment.where(:id.in => comment_ids)
      thread_ids = comments.collect{|c| c.comment_thread_id.to_s}
    end

    #thread_ids = c_results.collect{|c| c.comment_thread_id}
    #as soon as we can add comment thread id to the ES index, via Tire updgrade, we'll 
    #use ES instead of mongo to collect the thread ids

    #use the elasticsearch index instead to avoid DB hit

    self.class.trace_execution_scoped(['Custom/perform_search/collect_unique_thread_ids']) do
      original_thread_ids = results.collect{|r| r.id}

      #now add the original search thread ids
      thread_ids += original_thread_ids

      thread_ids = thread_ids.uniq
    end
    
    #now run one more search to harvest the threads and filter by group
    search = Tire::Search::Search.new 'comment_threads'
    search.filter(:terms, :thread_id => thread_ids)
    search.filter(:terms, commentable_id: params["commentable_ids"]) if params["commentable_ids"]
    search.filter(:term, course_id: params["course_id"]) if params["course_id"]

    search.size per_page
    search.from per_page * (page - 1)

    if params["group_id"]

      search.filter :or, [
        {:not => {:exists => {:field => :group_id}}},
        {:term => {:group_id => params["group_id"]}}

      ]
    end

    search.sort {|sort| sort.by sort_key, sort_order} if sort_key && sort_order 
    {results: search.results, total_results: thread_ids.length}
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

    # to_hash returns the following model for each thread
    #  title body course_id anonymous anonymous_to_peers commentable_id
    #  created_at updated_at at_position_list closed
    #    (all the above direct from the original document)
    #  id
    #    from doc._id
    #  user_id
    #    from doc.author_id
    #  username
    #    from doc.author_username
    #  votes
    #    from subdocument votes - {count, up_count, down_count, point}  
    #  abuse_flaggers
    #    from original document 
    #  tags
    #    deprecated - empty array
    #  type
    #    hardcoded "thread"
    #  group_id
    #    from orig doc
    #  pinned
    #    from orig doc
    #  comments_count
    #    count across all comments

    as_document.slice(*%w[title body course_id anonymous anonymous_to_peers commentable_id created_at updated_at at_position_list closed])
                     .merge("id" => _id, "user_id" => author_id,
                            "username" => author_username,
                            "votes" => votes.slice(*%w[count up_count down_count point]),
                            "abuse_flaggers" => abuse_flaggers,
                            "tags" => [],
                            "type" => "thread",
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

  def destroy_subscriptions
    subscriptions.delete_all
  end

  class << self
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer :perform_search, 'Custom/perform_search'
  end

end
