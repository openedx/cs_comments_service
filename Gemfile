source 'https://rubygems.org'
ruby "1.9.3"

gem 'pry'
gem 'pry-nav'
# gem 'debugger'

gem 'bundler'

gem 'rake'

gem 'sinatra'

gem 'yajl-ruby'

gem 'protected_attributes'

gem 'mongoid', "~>5.0"

gem 'delayed_job'
gem 'delayed_job_mongoid'#, :git => 'https://github.com/dementrock/delayed_job_mongoid.git', :tag => 'v1.0.8'

gem "enumerize"#, "~>0.8.0"
gem 'mongoid-tree', :git => 'https://github.com/macdiesel/mongoid-tree'
gem 'rs_voteable_mongo', :git => 'https://github.com/navneet35371/voteable_mongo.git'
gem 'mongoid_magic_counter_cache' #, :git => 'https://github.com/dementrock/mongoid-magic-counter-cache.git'

gem 'faker'
gem 'will_paginate_mongoid', "~>2.0"
gem 'rdiscount'
gem 'nokogiri'

gem 'tire', "0.6.2"
gem 'tire-contrib'

gem 'dalli'

gem 'rest-client'

group :test do
  gem 'rspec'
  gem 'rack-test', :require => "rack/test"
  gem 'guard'
  gem 'guard-unicorn'
  gem 'simplecov', :require => false
  # database_cleaner 1.5.1 which is compatible with Mongoid 5 has not been released
  # to rubygems yet, so pull it from github.
  gem 'database_cleaner', :git =>  'https://github.com/DatabaseCleaner/database_cleaner', :ref => 'b87f00320f8aa0f7e499d183128f05ce29cedc33'
end

gem 'newrelic_rpm'
gem 'unicorn'
gem "rack-timeout"
gem "i18n"
gem "rack-contrib", :git => 'https://github.com/rack/rack-contrib.git', :ref => '6ff3ca2b2d988911ca52a2712f6a7da5e064aa27'
