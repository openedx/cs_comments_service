var cnt = db.contents.find({_type: "CommentThread"}).count();
print ("Removing thread_type and endorsed_response_count from " + cnt + " comment threads");
db.contents.update(
    {_type: "CommentThread"},
    {$unset: {thread_type: "", endorsed_response_count: ""}},
    {multi: true}
);
print ("done.\n");

