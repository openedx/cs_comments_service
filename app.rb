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
  class << self; attr_accessor :config; end
  API_VERSION = 'v1'
  API_PREFIX = "/api/#{API_VERSION}"
end

if ["staging", "production", "loadtest", "edgestage","edgeprod"].include? environment
  require 'newrelic_rpm'
end

set :cache, Dalli::Client.new

application_yaml = ERB.new(File.read("config/application.yml")).result()
CommentService.config = YAML.load(application_yaml).with_indifferent_access

Tire.configure do
  url CommentService.config[:elasticsearch_server]
end

Mongoid.load!("config/mongoid.yml", environment)
Mongoid.logger.level = Logger::INFO

Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}

# Comment out observers until notifications are actually set up properly.
#Dir[File.dirname(__FILE__) + '/models/observers/*.rb'].each {|file| require file}
#Mongoid.observers = PostReplyObserver, PostTopicObserver, AtUserObserver
#Mongoid.instantiate_observers

APIPREFIX = CommentService::API_PREFIX
DEFAULT_PAGE = 1
DEFAULT_PER_PAGE = 20

if RACK_ENV.to_s != "test" # disable api_key auth in test environment
  before do
    error 401 unless params[:api_key] == CommentService.config[:api_key]
  end
end

# Enable the identity map. The middleware ensures that the identity map is
# cleared for every request.
Mongoid.identity_map_enabled = true
use Rack::Mongoid::Middleware::IdentityMap

# these files must be required in order
require './api/search'
require './api/commentables'
require './api/tags'
require './api/comment_threads'
require './api/comments'
require './api/users'
require './api/votes'
require './api/pins'
require './api/notifications_and_subscriptions'

if RACK_ENV.to_s == "development"
  get "#{APIPREFIX}/clean" do
    [Delayed::Backend::Mongoid::Job, Comment, CommentThread, User, Notification, Subscription, Activity].each(&:delete_all).each(&:remove_indexes).each(&:create_indexes)
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
