Change Log
----------

These are notable changes in cs_comments_service.  This is a rolling list of changes,
in roughly chronological order, most recent first.  Add your entries at or near
the top.  Include a label indicating the component affected.

**app.rb:** Return the correct Content-Type, application/json.

**api:** Add the ability to filter by commentable id to more endpoints
  (in particular, /threads).

**models:** added a new sorting key and index to `Comment` documents, removing the need
for certain hierarchical db queries.  Also added a copy of the author's username 
to `Comment` and `CommentThread` models, to reduce the number db queries.  
IMPORTANT: 
- these changes require a data backpopulation to be run BEFORE deploying 
updated code.  The backpopulation script is located at 
scripts/db/migrate-001-sk-author_username.js 
and should be run directly against your MongoDB instance.
- If your application is online while the migration script is running, you should run
the script a second time after deploying the application.  This is to backpopulate any
new content that may have been created between the first run and the application update.  

