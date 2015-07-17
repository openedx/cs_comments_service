print ("Removing context from all comment threads\n");
db.contents.update(
    {_type: "CommentThread"},
    {$unset: {context: ""}},
    {multi: true}
);
printjson (db.runCommand({ getLastError: 1, w: "majority", wtimeout: 5000 } ));
