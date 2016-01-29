print ("Removing thread_type from all comment threads\n");
db.contents.update(
    {_type: "CommentThread"},
    {$unset: {thread_type: ""}},
    {multi: true}
);
printjson (db.runCommand({ getLastError: 1, w: "majority", wtimeout: 5000 } ));
