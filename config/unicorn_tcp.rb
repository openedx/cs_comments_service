require 'tmpdir'
worker_processes Integer(ENV['WORKER_PROCESSES'] || 4)
timeout 25
preload_app true

listen_host = ENV['LISTEN_HOST'] || '0.0.0.0'
listen_port = ENV['LISTEN_PORT'] || '4567'
listen "#{listen_host}:#{listen_port}", :tcp_nopush => true

data_dir = ENV['DATA_DIR'] || Dir.tmpdir
pid "#{data_dir}/forum_unicorn.pid"

