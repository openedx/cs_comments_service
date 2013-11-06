worker_processes 4
timeout 25
preload_app true

after_fork do |server, worker|
  ::Mongoid.default_session.disconnect
end
