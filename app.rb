require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

env_index = ARGV.index("-e")
env_arg = ARGV[env_index + 1] if env_index
environment = env_arg || ENV["SINATRA_ENV"] || "development"
RACK_ENV = environment

module CommentService
  class << self; attr_accessor :config; end
  API_VERSION = 'v1'
  API_PREFIX = "/api/#{API_VERSION}"
end

CommentService.config = YAML.load_file("config/application.yml")

Mongoid.load!("config/mongoid.yml", environment)
Mongoid.logger.level = Logger::INFO

Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/models/observers/*.rb'].each {|file| require file}

Mongoid.observers = PostReplyObserver, PostTopicObserver, AtUserObserver
Mongoid.instantiate_observers

api_prefix = CommentService::API_PREFIX

get "#{api_prefix}/search/threads" do 

  sort_key_mapper = {
    "date" => :created_at,
    "votes" => :votes_point,
    "comments" => :comment_count,
  }

  sort_order_mapper = {
    "desc" => :desc,
    "asc" => :asc,
  }
  
  sort_key = sort_key_mapper[params["sort_key"]]
  sort_order = sort_order_mapper[params["sort_order"]]
  sort_keyword_valid = (!params["sort_key"] && !params["sort_order"] || sort_key && sort_order)

  if (!params["text"] && !params["tags"]) || !sort_keyword_valid
    {}.to_json
  else
    page = (params["page"] || 1).to_i
    per_page = (params["per_page"] || 20).to_i
    tags = params["tags"].split /,/ if params["tags"]
    #search = Tire::Search::Search.new 'comment_threads', page: page, per_page: per_page
    #search.query {|query| query.text(:_all, params["text"])} if params["text"]
    #search.filter :bool, :must => tags.map{|tag| {:term => {:tags_array => tag}}} if params["tags"]
    #search.highlight({title: { number_of_fragments: 0 } } , {body: { number_of_fragments: 0 } }, options: { tag: "<highlight>" })
    #search.query {|query| query.boolean {|boolean| tags.each {|tag| boolean.must { string "tags_array:#{tag}" }}}} if params["tags"]

    search = CommentThread.tire.search page: page, per_page: per_page do |search|
      if params["text"]
        search.query do |query|
          query.text(:_all, params["text"])
        end
        search.highlight({title: { number_of_fragments: 0 } } , {body: { number_of_fragments: 0 } }, options: { tag: "<highlight>" })
      end

      search.filter :bool, :must => tags.map{|tag| {:term => {:tags_array => tag}}} if params["tags"]
=begin
          if params["tags"]
            query.boolean do |boolean|
              for tag in tags
                boolean.must { string "tags_array:#{tag}" } 
              end
            end
          end
=end
      #search.filter(:term, commentable_id: params["commentable_id"]) if params["commentable_id"]
      #search.filter(:term, course_id: params["course_id"]) if params["course_id"]
      #search.sort {|sort| sort.by sort_key, sort_order} if sort_key && sort_order
    end

    num_pages = search.total_pages
    {
      collection: search.results.map{|t| CommentThread.search_result_to_hash(t, recursive: bool_recursive)},
      num_pages: num_pages,
      page: page,
    }.to_json
  end
end

delete "#{api_prefix}/:commentable_id/threads" do |commentable_id|
  commentable.comment_threads.destroy_all
  {}.to_json
end

get "#{api_prefix}/:commentable_id/threads" do |commentable_id|

  sort_key_mapper = {
    "date" => :created_at,
    "votes" => :"votes.point",
    "comments" => :comment_count,
  }

  sort_order_mapper = {
    "desc" => :desc,
    "asc" => :asc,
  }
  
  sort_key = sort_key_mapper[params["sort_key"]]
  sort_order = sort_order_mapper[params["sort_order"]]
  sort_keyword_valid = (!params["sort_key"] && !params["sort_order"] || sort_key && sort_order)
  if not sort_keyword_valid
    {}.to_json
  else
    page = (params["page"] || 1).to_i
    per_page = (params["per_page"] || 20).to_i
    comment_threads = commentable.comment_threads
    comment_threads = comment_threads.order_by("#{sort_key} #{sort_order}") if sort_key && sort_order
    num_pages = [1, (comment_threads.count / per_page.to_f).ceil].max
    page = [num_pages, [1, page].max].min
    paged_comment_threads = comment_threads.page(page).per(per_page)
    {
      collection: paged_comment_threads.map{|t| t.to_hash(recursive: bool_recursive)},
      num_pages: num_pages,
      page: page,
    }.to_json
  end
end

post "#{api_prefix}/:commentable_id/threads" do |commentable_id|
  thread = CommentThread.new(params.slice(*%w[title body course_id]).merge(commentable_id: commentable_id))
  thread.anonymous = bool_anonymous || false
  thread.tags = params["tags"] || ""
  thread.author = user
  thread.save
  if thread.errors.any?
    error 400, thread.errors.full_messages.to_json
  else
    user.subscribe(thread) if bool_auto_subscribe
    thread.to_hash.to_json
  end
end

get "#{api_prefix}/threads/tags" do
  CommentThread.tags.to_json
end

get "#{api_prefix}/threads/tags/autocomplete" do
  CommentThread.tags_autocomplete(params["value"].strip, max: 5, sort_by_count: true).map(&:first).to_json
end

get "#{api_prefix}/threads/:thread_id" do |thread_id|
  CommentThread.find(thread_id).to_hash(recursive: bool_recursive).to_json
end

put "#{api_prefix}/threads/:thread_id" do |thread_id|
  thread.update_attributes(params.slice(*%w[title body]))
  if params["tags"]
    thread.tags = params["tags"]
    thread.save
  end
  if thread.errors.any?
    error 400, thread.errors.full_messages.to_json
  else
    thread.to_hash.to_json
  end
end

post "#{api_prefix}/threads/:thread_id/comments" do |thread_id|
  comment = thread.comments.new(params.slice(*%w[body course_id]))
  comment.anonymous = bool_anonymous || false
  comment.author = user 
  comment.save
  if comment.errors.any?
    error 400, comment.errors.full_messages.to_json
  else
    user.subscribe(thread) if bool_auto_subscribe
    comment.to_hash.to_json
  end
end

delete "#{api_prefix}/threads/:thread_id" do |thread_id|
  thread.destroy
  thread.to_hash.to_json
end

get "#{api_prefix}/comments/:comment_id" do |comment_id|
  comment.to_hash(recursive: bool_recursive).to_json
end

put "#{api_prefix}/comments/:comment_id" do |comment_id|
  comment.update_attributes(params.slice(*%w[body endorsed]))
  if comment.errors.any?
    error 400, comment.errors.full_messages.to_json
  else
    comment.to_hash.to_json
  end
end

post "#{api_prefix}/comments/:comment_id" do |comment_id|
  sub_comment = comment.children.new(params.slice(*%w[body course_id]))
  sub_comment.anonymous = bool_anonymous || false
  sub_comment.author = user
  sub_comment.comment_thread = comment.comment_thread
  sub_comment.save
  if sub_comment.errors.any?
    error 400, sub_comment.errors.full_messages.to_json
  else
    user.subscribe(comment.comment_thread) if bool_auto_subscribe
    sub_comment.to_hash.to_json
  end
end

delete "#{api_prefix}/comments/:comment_id" do |comment_id|
  comment.destroy
  comment.to_hash.to_json
end

put "#{api_prefix}/comments/:comment_id/votes" do |comment_id|
  vote_for comment
end

delete "#{api_prefix}/comments/:comment_id/votes" do |comment_id|
  undo_vote_for comment
end

put "#{api_prefix}/threads/:thread_id/votes" do |thread_id|
  vote_for thread
end

delete "#{api_prefix}/threads/:thread_id/votes" do |thread_id|
  undo_vote_for thread
end

post "#{api_prefix}/users" do
  user = User.new(external_id: params["id"])
  user.username = params["username"]
  user.email = params["email"]
  user.save
  if user.errors.any?
    error 400, user.errors.full_messages.to_json
  else
    user.to_hash.to_json
  end
end

get "#{api_prefix}/users/:user_id" do |user_id|
  user.to_hash(complete: bool_complete).to_json
end

put "#{api_prefix}/users/:user_id" do |user_id|
  user = User.where(external_id: user_id).first
  if not user
    user = User.new(external_id: user_id)
  end
  user.update_attributes(params.slice(*%w[username email]))
  if user.errors.any?
    error 400, user.errors.full_messages.to_json
  else
    user.to_hash.to_json
  end
end

get "#{api_prefix}/users/:user_id/notifications" do |user_id|
  user.notifications.map(&:to_hash).to_json
end

post "#{api_prefix}/users/:user_id/subscriptions" do |user_id|
  user.subscribe(source).to_hash.to_json
end

delete "#{api_prefix}/users/:user_id/subscriptions" do |user_id|
  user.unsubscribe(source).to_hash.to_json
end

if environment.to_s == "development"
  get "#{api_prefix}/clean" do
    Comment.delete_all
    CommentThread.delete_all
    User.delete_all
    Notification.delete_all
    Subscription.delete_all
    {}.to_json
  end
end

error Moped::Errors::InvalidObjectId do
  error 400, ["requested object not found"].to_json
end

error Mongoid::Errors::DocumentNotFound do
  error 400, ["requested object not found"].to_json
end

error ArgumentError do
  error 400, [env['sinatra.error'].message].to_json
end
