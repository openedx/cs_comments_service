# USAGE

# 1). Use `bundle exec rake db:create_search_indexes` to generate
# new indexes with the appropriate mappings as declared in application
# model code.

# 2). Run this script for each of the two indexes created in the above
# step.  For example, if db:create_search_indexes outputs the following:
#
#   comment_threads_1234567890
#   comments_1234567890
#
# Then you need to run the following two commands (setting the
# elasticsearch url as needed):
#
#   ./migrate-index.sh http://my-es-host:9200 comment_threads comment_threads_1234567890
#   ./migrate-index.sh http://my-es-host:9200 comments comments_1234567890


# HOW IT WORKS

# ---T1---(W1)---T2---(W2)---T3--------->
#      \           \           \
#       \           \           incremental-copy-index completes
#        \           \
#         \           copy-index completes
#          \           alias moves
#           \           incremental-copy-index begins
#            \
#             copy-index begins
#

# During W1, the new index is created but is not yet live.  The current
# index's documents are copied into the new index, as of T1 (see
# copy-index.sh).

# At T2, when this initial copy finishes, the new index is made live and
# requests to the application begin using it (though it is still missing
# changes from W1).

# During W2, all documents in the old (previously live) index that were
# created or modified during W1 are copied into the newly-live index
# (see incremental-copy-index.sh).

# At T3, when the second copy finishes, the new (newly-live) index is up
# to date and the old index can be discarded.


# WARNING

# When performed while the application is online, the migration process
# is prone to a race condition, whose likelihood increases with the
# amount of write traffic against the application.

# Specifically, if a document is created or modified during W1, and the
# same document is modified (or deleted) during W2, the two
# modifications *may* be applied out of sequence, resulting in either a
# lost update or a reverted deletion.

# Therefore, manual steps must be taken to ensure the index and the
# source database are fully synchronized, if these tools are used for an
# online index migration.  Otherwise, consider closing your application
# instance for maintenance while migrating your indexes.


ES_URL=$1
ALIAS=$2
NEW_INDEX=$3

# determine the existing alias and set OLD_INDEX
OLD_INDEX=`curl -X GET $ES_URL/_alias/$ALIAS | jq -r 'keys[0]'`

echo old index: $OLD_INDEX
echo new index: $NEW_INDEX

if [ $OLD_INDEX = $NEW_INDEX ]; then
	echo "Alias ${ALIAS} already points to the new index.  Nothing to do."
	exit 0
fi

# regenerate presently existing documents in new index
./copy-index.sh $ES_URL $OLD_INDEX $ES_URL $NEW_INDEX

# move alias atomically to new index
BODY="
{
    \"actions\" : [
        {\"remove\": {\"index\" : \"${OLD_INDEX}\", \"alias\" : \"${ALIAS}\" } },
        {\"add\": {\"index\" : \"${NEW_INDEX}\", \"alias\" : \"${ALIAS}\" } }
    ]
}
"
curl -X POST "${ES_URL}/_aliases" -d "${BODY}"

# pick up any missed updates since the first copy
./incremental-copy-index.sh $ES_URL $OLD_INDEX $ES_URL $NEW_INDEX
