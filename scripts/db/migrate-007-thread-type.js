var cnt = db.contents.find({_type: "CommentThread"}).count();
var cnt_to_update = db.contents.find({_type: "CommentThread", thread_type: {$exists: false}}).count();
print ("Updating " + cnt_to_update + " of " + cnt + " comment threads with default thread_type");
db.contents.update(
    {_type: "CommentThread", thread_type: {$exists: false}},
    {$set: {thread_type: "discussion"}},
    {multi: true}
);
print ("done.\n");

var cnt_to_update = db.contents.find({_type: "CommentThread", endorsed_response_count: {$exists: false}}).count();
var cnt_updated = 0;
var pct;
print ("Updating " + cnt_to_update + " of " + cnt + " comment threads with endorsed_response_count");
db.contents.find(
    {_type: "CommentThread", endorsed_response_count: {$exists: false}},
    {_id: 1}
).forEach(function(doc) {
    var endorsedCount = db.contents.find(
        {comment_thread_id: doc._id, parent_id: {$exists: false}, endorsed: true}
    ).count();
    db.contents.update(
        {_id: doc._id},
        {$set: {endorsed_response_count: endorsedCount}}
    );
    cnt_updated += 1;
    if (cnt_updated % 100 == 0) {
        pct = (cnt_updated / cnt_to_update) * 100;
        print ("..." + cnt_updated + " of " + cnt_to_update + " completed (" + parseInt(pct) + "%)");
    }
});
print ("done.\n");
