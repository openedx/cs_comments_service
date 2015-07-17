print ("Adding context to all comment threads where it does not yet exist\n");
db.contents.update(
    {_type: "CommentThread", context: {$exists: false}},
    {$set: {context: "course"}},
    {multi: true}
);
printjson (db.runCommand({ getLastError: 1, w: "majority", wtimeout: 5000 } ));
