#!/bin/bash -xe
. /edx/app/forum/forum_env
export MONGOHQ_URL="mongodb://mongo.edx:27017/cs_comments_service_test"

cd /edx/app/forum/cs_comments_service

bundle install

# allow dependent services to finish start up (e.g. ElasticSearch, Mongo)
sleep 10

# Use 'bin/rspec -fd' to print test names for debugging
# Printing test names can be especially helpful for tracking down test
# failure differences between Travis and Mac, because tests are loaded
# and run in different orders.
bin/rspec
