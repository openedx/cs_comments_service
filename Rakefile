require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

application_yaml = ERB.new(File.read('config/application.yml')).result()


begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
rescue LoadError
  # no rspec available
end

Tire.configure do
  url YAML.load(application_yaml)['elasticsearch_server']
end

LOG = Logger.new(STDERR)

desc 'Load the environment'
task :environment do
  environment = ENV['SINATRA_ENV'] || 'development'
  Sinatra::Base.environment = environment
  Mongoid.load!('config/mongoid.yml')
  Mongoid.logger.level = Logger::INFO
  module CommentService
    class << self;
      attr_accessor :config;
    end
  end

  CommentService.config = YAML.load(application_yaml)

  Dir[File.dirname(__FILE__) + '/lib/**/*.rb'].each { |file| require file }
  Dir[File.dirname(__FILE__) + '/models/*.rb'].each { |file| require file }
end

Dir.glob('lib/tasks/*.rake').each { |r| import r }

task :console => :environment do
  binding.pry
end
