worker_processes 4
timeout 25
preload_app true

after_fork do
  ::Mongoid.default_session.disconnect
end
