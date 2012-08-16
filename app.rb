require 'rubygems'
require 'bundler'

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

CommentService.config = YAML.load_file("config/application.yml")

Mongoid.load!("config/mongoid.yml", environment)
Mongoid.logger.level = Logger::INFO

Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}
Dir[File.dirname(__FILE__) + '/models/observers/*.rb'].each {|file| require file}

Mongoid.observers = PostReplyObserver, PostTopicObserver, AtUserObserver
Mongoid.instantiate_observers

APIPREFIX = CommentService::API_PREFIX
DEFAULT_PAGE = 1
DEFAULT_PER_PAGE = 20

# these files must be required in order

require './api/search'
require './api/commentables'
require './api/tags'
require './api/comment_threads'
require './api/comments'
require './api/users'
require './api/votes'
require './api/notifications_and_subscriptions'

if environment.to_s == "development"
  get "#{APIPREFIX}/clean" do
    [Comment, CommentThread, User, Notification, Subscription, Activity].each(&:delete_all)
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
