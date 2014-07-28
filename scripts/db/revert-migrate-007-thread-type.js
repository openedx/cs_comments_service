var cnt = db.contents.find({_type: "CommentThread", thread_type: {$exists: true}}).count();
print ("Removing thread_type from " + cnt + " comment threads");
db.contents.update(
    {_type: "CommentThread"},
    {$unset: {thread_type: ""}},
    {multi: true}
);
print ("done.\n");
