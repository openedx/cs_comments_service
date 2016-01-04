require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
rescue LoadError
  # no rspec available
end

LOG = Logger.new(STDERR)

desc 'Load the environment'
task :environment do
  # Load all of app.rb to keep rake and the app as similar as possible.
  # Without this, we had run into bugs where certain overriding fixes in app.rb
  # were not used from the rake tasks.
  require File.dirname(__FILE__) + '/app.rb'
end

task :console => :environment do
  binding.pry
end

Dir.glob('lib/tasks/*.rake').each { |r| import r }
