print ("Add the new indexes for the context field");
db.contents.ensureIndex({ _type: 1, course_id: 1, context: 1, pinned: -1, created_at: -1 }, {background: true})
db.contents.ensureIndex({ _type: 1, commentable_id: 1, context: 1, pinned: -1, created_at: -1 }, {background: true})

print ("Adding context to all comment threads where it does not yet exist\n");
var bulk = db.contents.initializeUnorderedBulkOp();
bulk.find( {_type: "CommentThread", context: {$exists: false}} ).update(  {$set: {context: "course"}} );
bulk.execute();
printjson (db.runCommand({ getLastError: 1, w: "majority", wtimeout: 5000 } ));
