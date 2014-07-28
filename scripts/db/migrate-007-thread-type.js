var cnt = db.contents.find({_type: "CommentThread"}).count();
var cnt_to_update = db.contents.find({_type: "CommentThread", thread_type: {$exists: false}}).count();
print ("Updating " + cnt_to_update + " of " + cnt + " comment threads with default thread_type");
db.contents.update(
    {_type: "CommentThread", thread_type: {$exists: false}},
    {$set: {thread_type: "discussion"}},
    {multi: true}
);
print ("done.\n");
