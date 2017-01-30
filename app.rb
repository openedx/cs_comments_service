require 'rubygems'
require 'bundler'
require 'erb'

Bundler.setup
Bundler.require

env_index = ARGV.index("-e")
env_arg = ARGV[env_index + 1] if env_index
environment = env_arg || ENV["SINATRA_ENV"] || "development"

RACK_ENV = environment
module CommentService
  class << self
    attr_accessor :config
    attr_accessor :blocked_hashes

    def search_enabled?
      self.config[:enable_search]
    end
  end
  API_VERSION = 'v1'
  API_PREFIX = "/api/#{API_VERSION}"
end

if ENV["ENABLE_GC_PROFILER"]
  GC::Profiler.enable
end

def get_logger(progname, threshold=nil)
  logger = Logger.new(STDERR)
  logger.progname = progname
  logger.level = threshold || Logger::INFO
  logger
end

application_yaml = ERB.new(File.read("config/application.yml")).result()
CommentService.config = YAML.load(application_yaml).with_indifferent_access

# Raise sinatra-param exceptions so that we can process, and respond to, them appropriately
set :raise_sinatra_param_exceptions, true

# Setup Mongo
Mongoid.load!("config/mongoid.yml", environment)
Mongoid.logger.level = Logger::INFO
Mongo::Logger.logger.level = ENV["ENABLE_MONGO_DEBUGGING"] ? Logger::DEBUG : Logger::INFO


$is_not_rake_search_initialize = defined?(RAKE_SEARCH_INITIALIZE) === nil || RAKE_SEARCH_INITIALIZE === false

# Setup Elasticsearch
# NOTE (CCB): If you want to see all data sent to Elasticsearch (e.g. for debugging purposes), set the tracer argument
# to the value of a logger.
# Example: Elascisearch.Client.new(tracer: get_logger('elasticsearch.tracer'))
if $is_not_rake_search_initialize
  Elasticsearch::Model.client = Elasticsearch::Client.new(
      host: CommentService.config[:elasticsearch_server],
      logger: get_logger('elasticsearch', Logger::WARN)
  )
else
  # avoid misleading fatal errors during initialization
  Elasticsearch::Model.client = Elasticsearch::Client.new(
      host: CommentService.config[:elasticsearch_server],
      log: false
  )
end

# Setup i18n
I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'locale', '*.yml').to_s]
I18n.default_locale = CommentService.config[:default_locale]
I18n.enforce_available_locales = false
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
use Rack::Locale

helpers do
  def t(*args)
    I18n.t(*args)
  end
end

Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each { |file| require file }
Dir[File.dirname(__FILE__) + '/models/*.rb'].each { |file| require file }
Dir[File.dirname(__FILE__) + '/presenters/*.rb'].each { |file| require file }


$is_not_rake_search_call = defined?(RAKE_SEARCH) === nil || RAKE_SEARCH === false
if $is_not_rake_search_call
  # Ensure Elasticsearch index mappings exist, unless we are creating it in the rake search initialize
  Comment.put_search_index_mapping
  CommentThread.put_search_index_mapping
end

# Comment out observers until notifications are actually set up properly.
#Dir[File.dirname(__FILE__) + '/models/observers/*.rb'].each {|file| require file}
#Mongoid.observers = PostReplyObserver, PostTopicObserver, AtUserObserver
#Mongoid.instantiate_observers

APIPREFIX = CommentService::API_PREFIX
DEFAULT_PAGE = 1
DEFAULT_PER_PAGE = 20

before do
  pass if request.path_info == '/heartbeat'
  api_key = CommentService.config[:api_key]
  error 401 unless params[:api_key] == api_key or env["HTTP_X_EDX_API_KEY"] == api_key
end

before do
  content_type "application/json"
end

# use yajl implementation for to_json.
# https://github.com/brianmario/yajl-ruby#json-gem-compatibility-api
#
# In addition to performance advantages over the standard JSON gem,
# this avoids a bug with non-BMP characters.  For more info see:
# https://github.com/rails/rails/issues/3727
require 'yajl/json_gem'

# patch json serialization of ObjectIds to work properly with yajl.
# See https://groups.google.com/forum/#!topic/mongoid/MaXFVw7D_4s
# Note that BSON was moved from Moped::BSON::ObjectId to BSON::ObjectId
module BSON
  class ObjectId
    def as_json(options = {})
      self.to_s
    end
  end
end

# Patch json serialization of Time Objects
class Time
  # Returns a hash, that will be turned into a JSON object and represent this
  # object.
  # Note that this was done to prevent milliseconds from showing up in the JSON response thus breaking
  # API compatibility for downstream clients.
  def as_json(options = {})
    utc().strftime("%Y-%m-%dT%H:%M:%SZ")
  end
end


# these files must be required in order
require './api/search'
require './api/commentables'
require './api/comment_threads'
require './api/comments'
require './api/users'
require './api/votes'
require './api/flags'
require './api/pins'
require './api/notifications_and_subscriptions'
require './api/notifications'

if RACK_ENV.to_s == "development"
  get "#{APIPREFIX}/clean" do
    [Delayed::Backend::Mongoid::Job, Comment, CommentThread, User, Notification, Subscription, Activity].each(&:delete_all).each(&:remove_indexes).each(&:create_indexes)
    {}.to_json
  end
end

error Mongo::Error::InvalidDocument do
  error 400, [t(:requested_object_not_found)].to_json
end

error Mongoid::Errors::DocumentNotFound do
  error 400, [t(:requested_object_not_found)].to_json
end

error ArgumentError do
  error 400, [env['sinatra.error'].message].to_json
end

CommentService.blocked_hashes = Content.mongo_client[:blocked_hash].find(nil, projection: {hash: 1}).map { |d| d["hash"] }

def get_db_is_master
  Mongoid::Clients.default.command(isMaster: 1)
end

def elasticsearch_health
  Elasticsearch::Model.client.cluster.health
end


def is_mongo_available?
  begin
    response = get_db_is_master
    return response.ok? && (response.documents.first['ismaster'] == true)
  rescue
    # ignored
  end

  false
end

def is_elasticsearch_available?
  begin
    health = elasticsearch_health
    return !health['timed_out'] && %w(yellow green).include?(health['status'])
  rescue
    # ignored
  end

  false
end

get '/heartbeat' do
  error 500, JSON.generate({OK: false, check: :db}) unless is_mongo_available?
  error 500, JSON.generate({OK: false, check: :es}) unless is_elasticsearch_available?
  JSON.generate({OK: true})
end

get '/selftest' do
  begin
    t1 = Time.now
    status = {
        db: get_db_is_master,
        es: elasticsearch_health,
        last_post_created: (Content.last.created_at rescue nil),
        total_posts: Content.count,
        total_users: User.count,
        elapsed_time: Time.now - t1
    }
    JSON.generate(status)
  rescue => ex
    [500,
     {'Content-Type' => 'text/plain'},
     "#{ex.backtrace.first}: #{ex.message} (#{ex.class})\n\t#{ex.backtrace[1..-1].join("\n\t")}"
    ]
  end
end
