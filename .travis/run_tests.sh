#!/bin/bash -xe
. /edx/app/forum/forum_env
export MONGOHQ_URL="mongodb://mongo.edx:27017/cs_comments_service_test"
export SEARCH_SERVER="http://es.edx:9200"

cd /edx/app/forum/cs_comments_service

bundle install

bin/rake search:initialize
bin/rspec
