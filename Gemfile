source 'https://rubygems.org'
ruby "2.4.1"

gem 'pry'
gem 'pry-nav'

# Use with command-line debugging, but not RubyMine
#gem 'debugger'

gem 'bundler'

gem 'rake'

gem 'sinatra'
gem 'sinatra-param', '~> 1.4'

gem 'yajl-ruby', '~> 1.3.1'

gem 'activemodel', '~> 4.2.8'

gem 'mongoid', '~> 5.0.0'
gem 'bson'
gem 'bson_ext'
gem 'protected_attributes'

gem 'delayed_job'
gem 'delayed_job_mongoid'

gem "enumerize"
gem 'mongoid-tree', :git => 'https://github.com/macdiesel/mongoid-tree'
gem 'rs_voteable_mongo', :git => 'https://github.com/navneet35371/voteable_mongo.git'
gem 'mongoid_magic_counter_cache'

# Before updating will_paginate version, we need to make sure that property 'total_entries'
# exists otherwise use updated property name to fetch total collection count in lib/helpers.rb's
# function 'handle_threads_query'.
gem 'will_paginate_mongoid', "~>2.0"
gem 'rdiscount'
gem 'nokogiri', "~>1.8.1"

gem 'elasticsearch', '~> 1.1.2'
gem 'elasticsearch-model', '~> 0.1.9'

gem 'dalli'

gem 'rest-client'

group :test do
  gem 'codecov', :require => false
  gem 'mongoid_cleaner', '~> 1.2.0'
  gem 'factory_girl', '~> 4.0'
  gem 'faker', '~> 1.6'
  gem 'guard'
  gem 'guard-unicorn'
  gem 'rack-test', :require => 'rack/test'
  gem 'rspec', '~> 3.6.0'
  gem 'rspec-its'
  gem 'rspec-collection_matchers'
  gem 'webmock', '~> 3.0.1'
end

group 'newrelic_rpm' do
  gem 'newrelic_rpm'
end

gem 'unicorn'
gem "rack-timeout"
gem "i18n"
gem "rack-contrib", :git => 'https://github.com/rack/rack-contrib.git', :ref => '6ff3ca2b2d988911ca52a2712f6a7da5e064aa27'

