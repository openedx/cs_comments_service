#!/bin/bash -xe
. /edx/app/forum/forum_env
. /edx/app/forum/ruby_env
export MONGOHQ_URL="mongodb://mongo.edx:27017/cs_comments_service_test"

cd /edx/app/forum/cs_comments_service

#gem update bundler # Ensure we use the latest version of bundler. Travis' default version of outdated.

bundle install

bundle exec rspec
