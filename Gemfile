source "https://rubygems.org"

ruby "~> 3.2.2"

gem "pry"
gem "pry-nav"

# Use with command-line debugging, but not RubyMine
# gem "debugger"

gem "bundler"

gem "rake"

gem "sinatra"
gem "sinatra-param"

gem "yajl-ruby"

gem "activemodel"
gem "protected_attributes_continued"

gem "mongoid"
gem "bson"
gem "bson_ext"

gem "delayed_job"
gem "delayed_job_mongoid"

gem "enumerize"
gem "mongoid-tree"
gem "rs_voteable_mongo"
gem "mongoid_magic_counter_cache"

# Before updating will_paginate version, we need to make sure that property "total_entries"
# exists otherwise use updated property name to fetch total collection count in lib/helpers.rb"s
# function "handle_threads_query".
gem "will_paginate_mongoid", "~>2.0"
gem "rdiscount"
gem "nokogiri"

gem "elasticsearch", "~> 7.13.3"
gem "elasticsearch-model", "~> 7.2.1"

gem "dalli"

gem "rest-client"

group :test do
    gem "codecov", :require => false
    gem "mongoid_cleaner"
    gem "factory_bot"
    gem "faker"
    gem "guard"
    gem "guard-unicorn"
    gem "rack-test", :require => "rack/test"
    gem "rspec"
    gem "rspec-its"
    gem "rspec-collection_matchers"
    gem "webmock"
end

group "newrelic_rpm" do
    gem "newrelic_rpm"
end

gem "unicorn"
gem "rack-timeout"
gem "i18n"
gem "rack-contrib"

gem "timecop"
