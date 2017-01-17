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
  # Load all of app.rb, because it is too easy to introduce bugs otherwise where Rake
  # does not have a fix or config that is added to app.rb.
  require File.dirname(__FILE__) + '/app.rb'
end

Dir.glob('lib/tasks/*.rake').each { |r| import r }

task :console => :environment do
  binding.pry
end
