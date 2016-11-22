#!/bin/bash -xe
. /edx/app/forum/forum_env
. /edx/app/forum/ruby_env

gem update bundler # Ensure we use the latest version of bundler. Travis' default version of outdated.

# install java
curl -L -C - -b "oraclelicense=accept-securebackup-cookie" -O http://download.oracle.com/otn-pub/java/jdk/8u111-b14/jdk-8u111-linux-x64.tar.gz
tar -xvzf jdk-8u111-linux-x64.tar.gz -C /opt
export JAVA_HOME=/opt/jdk1.8.0_111/
export PATH=/opt/jdk1.8.0_111/bin:$PATH

# Run Elasticsearch as a daemon
curl -O https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.13.zip
unzip elasticsearch-0.90.13.zip
elasticsearch-0.90.13/bin/elasticsearch
sleep 10

# Run MongoDB as a daemon
curl -O https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-3.0.12.tgz
tar -zxf mongodb-linux-x86_64-3.0.12.tgz
export PATH=mongodb-linux-x86_64-3.0.12/bin:$PATH
mkdir -p ./mongo/db
mkdir -p ./mongo/log
mongod --fork --dbpath ./mongo/db --logpath ./mongo/log/mongodb.log --storageEngine wiredTiger

bundle exec rspec
