print ("Adding thread_type to all comment threads where it does not yet exist\n");
db.contents.update(
    {_type: "CommentThread", thread_type: {$exists: false}},
    {$set: {thread_type: "discussion"}},
    {multi: true}
);
printjson (db.runCommand({ getLastError: 1, w: "majority", wtimeout: 5000 } ));
