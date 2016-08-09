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
  end
  API_VERSION = 'v1'
  API_PREFIX = "/api/#{API_VERSION}"
end

if ENV["ENABLE_GC_PROFILER"]
  GC::Profiler.enable
end

application_yaml = ERB.new(File.read("config/application.yml")).result()
CommentService.config = YAML.load(application_yaml).with_indifferent_access

Tire.configure do
  url CommentService.config[:elasticsearch_server]
  logger STDERR if ENV["ENABLE_ELASTICSEARCH_DEBUGGING"]
end

Mongoid.load!("config/mongoid.yml", environment)
Mongoid.logger.level = Logger::INFO
Mongo::Logger.logger.level = ENV["ENABLE_MONGO_DEBUGGING"] ? Logger::DEBUG : Logger::INFO

# set up i18n
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

Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/presenters/*.rb'].each {|file| require file}

# Ensure elasticsearch index mappings exist.
Comment.put_search_index_mapping
CommentThread.put_search_index_mapping

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
    def to_json
      self.to_s.to_json
    end
  end
end

# Patch json serialization of Time Objects
class Time
  # Returns a hash, that will be turned into a JSON object and represent this
  # object.
  # Note that this was done to prevent milliseconds from showing up in the JSON response thus breaking
  # API compatibility for downstream clients.
  def to_json(*)
    '"' + utc().strftime("%Y-%m-%dT%H:%M:%SZ") + '"'
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

CommentService.blocked_hashes = Content.mongo_client[:blocked_hash].find(nil, projection: {hash: 1}).map {|d| d["hash"]}

def get_db_is_master
  Mongoid::Clients.default.command(isMaster: 1)
end

def get_es_status
  res = Tire::Configuration.client.get Tire::Configuration.url
  JSON.parse res.body
end

get '/heartbeat' do
  # mongo is reachable and ready to handle requests
  db_ok = false
  begin
    res = get_db_is_master
    db_ok = res.ok? && res.documents.first['ismaster'] == true
  rescue
  end
  error 500, JSON.generate({"OK" => false, "check" => "db"}) unless db_ok

  # E_S is reachable and ready to handle requests
  es_ok = false
  begin
    es_status = get_es_status
    es_ok = es_status["status"] == 200
  rescue
  end
  error 500, JSON.generate({"OK" => false, "check" => "es"}) unless es_ok

  JSON.generate({"OK" => true})
end

get '/selftest' do
  begin
    t1 = Time.now
    status = {
      "db" => get_db_is_master,
      "es" => get_es_status,
      "last_post_created" => (Content.last.created_at rescue nil),
      "total_posts" => Content.count,
      "total_users" => User.count,
      "elapsed_time" => Time.now - t1
    }
    JSON.generate(status)
  rescue => ex
    [ 500,
      {'Content-Type' => 'text/plain'},
      "#{ex.backtrace.first}: #{ex.message} (#{ex.class})\n\t#{ex.backtrace[1..-1].join("\n\t")}"
    ]
  end
end
