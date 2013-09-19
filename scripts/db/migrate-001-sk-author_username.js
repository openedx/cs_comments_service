
print ("backpopulating author_username into contents collection");
var tot = db.users.count();
print ("found " + tot + " users to process...");
var cnt = 0;
db.users.find({}, {external_id:1, username:1}).forEach(function (doc) {
    db.contents.update(
        {author_id:doc["external_id"], author_username:{$exists:false}},
        {$set:{author_username:doc["username"]}},
        {multi:true}
        );
    cnt += 1;
    if (cnt == tot) {
        print("done!");
    } else if (cnt % 1000 === 0) {
        print("processed " + cnt + " records (" + parseInt((cnt/tot)*100) + "% complete)");
    }
});

print ("backpopulating content with orphaned author ids");
db.contents.update({author_username:{$exists:false}}, {$set:{author_username:null}}, {multi:true});
print ("done!");

print ("backpopulating hierarchical sorting keys into contents collection");
var tot = db.contents.find({"_type":"Comment","sk":{$exists:false}}).count();
print ("found " + tot + " comments to process...");
var cnt = 0;
db.contents.find({"_type":"Comment","sk":{$exists:false}}).forEach(function (doc) {
    var i, sort_ids;
    if (typeof(doc.sk)==="undefined") {
        if (typeof(doc.parent_ids)==="undefined") {
            sort_ids = [];
        } else {
            sort_ids = doc.parent_ids.slice(0);
        }
        sort_ids.push(doc._id);
        doc.sk = sort_ids.map(function (oid) {return oid.str}).join("-");
        db.contents.save(doc);
    }
    cnt += 1;
    if (cnt == tot) {
        print("done!");
    } else if (cnt % 1000 === 0) {
        print("processed " + cnt + " records (" + parseInt((cnt/tot)*100) + "% complete)");
    }
});

print ("creating index on new sorting keys...");
db.contents.ensureIndex({"sk":1})
print ("all done!");

