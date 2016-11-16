#!/bin/bash -xe
gem update bundler # Ensure we use the latest version of bundler. Travis' default version of outdated.

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
