require 'tmpdir'

# Load app.rb to get all dependencies.
require File.expand_path('../../app.rb', __FILE__)

# Make sure elasticsearch is configured correctly
UnicornHelpers.exit_on_invalid_index

worker_processes Integer(ENV['WORKER_PROCESSES'] || 4)
timeout 25
preload_app true

service_name = 'forum'
if ENV['ENABLE_DATA_DOG']
  require 'ddtrace'
  # Add Datadog APM configuration
  Datadog.configure do |c|
    c.tracing.instrument :rails, service_name: service_name
    c.tracing.instrument :sinatra, service_name: service_name
  end
end

listen_host = ENV['LISTEN_HOST'] || '0.0.0.0'
listen_port = ENV['LISTEN_PORT'] || '4567'
listen "#{listen_host}:#{listen_port}", :tcp_nopush => true, :backlog => 512

data_dir = ENV['DATA_DIR'] || Dir.tmpdir
pid "#{data_dir}/forum_unicorn.pid"

after_fork do |server, worker|
  ::Mongoid.default_client.close
  ::Mongoid.default_client.reconnect
end

before_fork do |server, worker|
  ::Mongoid.disconnect_clients
end
