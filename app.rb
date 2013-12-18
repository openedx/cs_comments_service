require 'rubygems'
require 'bundler'
require 'erb'

Bundler.setup
Bundler.require

require 'tire/queries/more_like_this'

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

if ["staging", "production", "loadtest", "edgestage","edgeprod"].include? environment
  require 'newrelic_rpm'
  require 'new_relic/agent/method_tracer'
  Moped::Session.class_eval do
    include NewRelic::Agent::MethodTracer
    add_method_tracer :new
    add_method_tracer :use
    add_method_tracer :login
  end
  Moped::Cluster.class_eval do
    include NewRelic::Agent::MethodTracer
    add_method_tracer :with_primary
    add_method_tracer :nodes
  end
  Moped::Node.class_eval do
    include NewRelic::Agent::MethodTracer
    add_method_tracer :command
    add_method_tracer :connect
    add_method_tracer :flush
    add_method_tracer :refresh
  end
end

if ENV["ENABLE_GC_PROFILER"]
  GC::Profiler.enable
end

application_yaml = ERB.new(File.read("config/application.yml")).result()
CommentService.config = YAML.load(application_yaml).with_indifferent_access

Tire.configure do
  url CommentService.config[:elasticsearch_server]
end

Mongoid.load!("config/mongoid.yml", environment)
Mongoid.logger.level = Logger::INFO
Moped.logger.level = ENV["ENABLE_MOPED_DEBUGGING"] ? Logger::DEBUG : Logger::INFO

# set up i18n
I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'locale', '*.yml').to_s]
I18n.default_locale = CommentService.config[:default_locale]
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)

helpers do
  def t(*args)
    I18n.t(*args)
  end
end

Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/presenters/*.rb'].each {|file| require file}

# Comment out observers until notifications are actually set up properly.
#Dir[File.dirname(__FILE__) + '/models/observers/*.rb'].each {|file| require file}
#Mongoid.observers = PostReplyObserver, PostTopicObserver, AtUserObserver
#Mongoid.instantiate_observers

APIPREFIX = CommentService::API_PREFIX
DEFAULT_PAGE = 1
DEFAULT_PER_PAGE = 20

if RACK_ENV.to_s != "test" # disable api_key auth in test environment
  before do
    api_key = CommentService.config[:api_key]
    error 401 unless params[:api_key] == api_key or env["HTTP_X_EDX_API_KEY"] == api_key
  end
end

before do
  content_type "application/json"
end

if ENV["ENABLE_IDMAP_LOGGING"]

  after do
    idmap = Mongoid::Threaded.identity_map
    vals = {
      "pid" => Process.pid,
      "dyno" => ENV["DYNO"],
      "request_id" => params[:request_id]
    }
    idmap.each {|k, v| vals["idmap_count_#{k.to_s}"] = v.size }
    logger.info vals.map{|e| e.join("=") }.join(" ")
  end

end

# Enable the identity map. The middleware ensures that the identity map is
# cleared for every request.
Mongoid.identity_map_enabled = true
use Rack::Mongoid::Middleware::IdentityMap


# use yajl implementation for to_json.
# https://github.com/brianmario/yajl-ruby#json-gem-compatibility-api
#
# In addition to performance advantages over the standard JSON gem,
# this avoids a bug with non-BMP characters.  For more info see:
# https://github.com/rails/rails/issues/3727
require 'yajl/json_gem'

# patch json serialization of ObjectIds to work properly with yajl.
# See https://groups.google.com/forum/#!topic/mongoid/MaXFVw7D_4s
module Moped
  module BSON
    class ObjectId
      def to_json
        self.to_s.to_json
      end
    end
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

error Moped::Errors::InvalidObjectId do
  error 400, [t(:requested_object_not_found)].to_json
end

error Mongoid::Errors::DocumentNotFound do
  error 400, [t(:requested_object_not_found)].to_json
end

error ArgumentError do
  error 400, [env['sinatra.error'].message].to_json
end

CommentService.blocked_hashes = Content.mongo_session[:blocked_hash].find.select(hash: 1).each.map {|d| d["hash"]}

