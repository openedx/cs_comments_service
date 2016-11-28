#!/bin/bash -xe
. /edx/app/forum/forum_env
export MONGOHQ_URL="mongodb://mongo.edx:27017/cs_comments_service_test"

cd /edx/app/forum/cs_comments_service

bundle install

bundle exec rspec
