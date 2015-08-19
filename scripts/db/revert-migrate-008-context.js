print ("remove the indexes for the context field");
db.contents.dropIndex({ _type: 1, course_id: 1, context: 1, pinned: -1, created_at: -1 })
db.contents.dropIndex({ _type: 1, commentable_id: 1, context: 1, pinned: -1, created_at: -1 })

print ("Removing context from all comment threads\n");
var bulk = db.contents.initializeUnorderedBulkOp();
bulk.find( {_type: "CommentThread", context: {$exists: true}} ).update(  {$unset: {context: ""}} );
bulk.execute();
printjson (db.runCommand({ getLastError: 1, w: "majority", wtimeout: 5000 } ));
