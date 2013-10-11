db.contents.dropIndex({_type: 1, course_id: 1, pinned: -1, comment_count: -1, created_at: -1})
db.contents.dropIndex({_type: 1, course_id: 1, pinned: -1, "votes.point": -1, created_at: -1})
