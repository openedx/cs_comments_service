#!/usr/bin/env bash

#
# Thin wrapper around stream2es.
#
# https://github.com/elasticsearch/stream2es
# 
# Copies an index from an elasticsearch source server to a target server. 
# The target server can be the same as the source.
#
# Requires jq
#
# http://stedolan.github.io/jq/
#
# Assumes that both stream2es and jq are on your PATH.
#
# Example:
#
# ./incremental-copy-index.sh http://localhost:9200 source_index http://localhost:9200 target_index
#

SOURCE_SERVER=$1
SOURCE_INDEX=$2
TARGET_SERVER=$3
TARGET_INDEX=$4

WORKERS="6"
#
# Statistical breakdown of date fields on the target index to determine 
# range limits for the subsequent query of the source index.
STATS=$(curl -s -XPOST "${TARGET_SERVER}/${TARGET_INDEX}/_search" -d @query-max-date.json)

# Returns a document containing
# "facets": {
#    "created_at_stats": {
#       "_type": "statistical",
#       "count": 802103,
#       "total": 1108393376211744500,
#       "min": 1345745023000,
#       "max": 1399317877000,
#       "mean": 1381859158003.08,
#       "sum_of_squares": 1.5318040597253865e+30,
#       "variance": 200126588772432280000,
#       "std_deviation": 14146610504.726292
#    },
#    "updated_at_stats": {
#       "_type": "statistical",
#       "count": 802103,
#       "total": 1108407292058564700,
#       "min": 1345745083000,
#       "max": 1399317877000,
#       "mean": 1381876507204.891,
#       "sum_of_squares": 1.5318424128841502e+30,
#       "variance": 199993733758660100000,
#       "std_deviation": 14141914076.908403
#    }
# }

# extract the max create and update time in millis since epoch
MAX_CREATED_AT=$( echo $STATS | jq -r '.facets.created_at_stats.max' )
MAX_UPDATED_AT=$( echo $STATS | jq -r '.facets.updated_at_stats.max' )

# expand the lower bound of the query by a second, allowing for
# latency between writes in the ruby application and replication
# to elasticsearch.
MAX_CREATED_AT=$((MAX_CREATED_AT-1000))
MAX_UPDATED_AT=$((MAX_UPDATED_AT-1000))

echo "Updating the target indices with records added since ${MAX_CREATED_AT} or updated since ${MAX_UPDATED_AT}"

# Finds records in the source that are newer than the latest
# document in the target.
QUERY="
{
   \"query\":{
      \"filtered\":{
         \"query\":{
            \"match_all\":{

            }
         },
         \"filter\":{
            \"or\":{
               \"filters\":[
                  {
                     \"range\":{
                        \"created_at\":{
                           \"from\":\"${MAX_CREATED_AT}\",
                           \"to\":\"now\"
                        }
                     }
                  },
                  {
                     \"range\":{
                        \"updated_at\":{
                           \"from\":\"${MAX_UPDATED_AT}\",
                           \"to\":\"now\"
                        }
                     }
                  }
               ]
            }
         }
      }
   }
}
"

echo $QUERY

stream2es es -w ${WORKERS} --query "${QUERY}" --source "${SOURCE_SERVER}/${SOURCE_INDEX}" --target "${TARGET_SERVER}/${TARGET_INDEX}"
