db.contents.update(
    {_type: "CommentThread", thread_type: {$exists: false}},
    {$set: {thread_type: "discussion"}},
    {multi: true}
);
db.contents.find(
    {_type: "CommentThread"},
    {_id: 1}
).forEach(function(doc) {
    var endorsedCount = db.contents.find(
        {comment_thread_id: doc._id, parent_id: {$exists: false}, endorsed: true}
    ).count();
    db.contents.update(
        {_id: doc._id},
        {$set: {endorsed_response_count: endorsedCount}}
    );
});
