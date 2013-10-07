db.contents.ensureIndex({ sk: 1 }, { background: true, safe: true })

db.contents.dropIndex({ comment_thread_id: 1, updated_at: 1 })
db.contents.dropIndex({ comment_thread_id: 1, sk: 1 })
db.contents.dropIndex({ comment_thread_id: 1, endorsed: 1 })
db.contents.dropIndex({ _type: 1, course_id: 1, pinned: -1, created_at: -1 })
