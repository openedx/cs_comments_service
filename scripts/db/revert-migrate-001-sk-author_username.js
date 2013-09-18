print ("removing fields 'sk' and 'author_username' from contents collection...");
db.contents.update({}, {$unset:{"sk":1, "author_username":1}}, { multi: true });
print ("removing index on contents.sk");
db.contents.dropIndex({"sk":1});
print ("all done!");

