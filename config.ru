require "rack-timeout"
use Rack::Timeout           # Call as early as possible so rack-timeout runs before other middleware.
Rack::Timeout.timeout = 20

require "mongoid"
use Mongoid::QueryCache::Middleware

require './app'
run Sinatra::Application

