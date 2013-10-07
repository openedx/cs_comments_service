db.contents.ensureIndex({ _type: 1, comment_thread_id: 1, author_id: 1, updated_at: 1 }, { background: true })
db.contents.ensureIndex({ comment_thread_id: 1, sk: 1 }, { background: true, sparse: true })
db.contents.ensureIndex({ comment_thread_id: 1, endorsed: 1 }, { background: true, sparse: true })
db.contents.ensureIndex({ _type: 1, course_id: 1, pinned: -1, created_at: -1 }, { background: true })

db.contents.dropIndex({ sk: 1 }) // the new one (created above) supersedes this
