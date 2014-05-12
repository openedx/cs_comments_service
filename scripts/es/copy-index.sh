#!/usr/bin/env bash

#
# Thin wrapper around stream2es.
#
# https://github.com/elasticsearch/stream2es
# 
# Copies an index from an elasticsearch source server to a target server. 
# The target server can be the same as the source.
#
# Example:
#
# ./copy-index.sh http://localhost:9200 source_index http://localhost:9200 target_index
#

SOURCE_SERVER=$1
SOURCE_INDEX=$2
TARGET_SERVER=$3
TARGET_INDEX=$4

WORKERS="6"

stream2es es -w ${WORKERS} --source "${SOURCE_SERVER}/${SOURCE_INDEX}" --target "${TARGET_SERVER}/${TARGET_INDEX}"
