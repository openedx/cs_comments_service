db.users.dropIndex({ external_id: 1 }) // drop the non-unique one
db.users.ensureIndex({ external_id: 1 }, { unique: true, background: true })
db.subscriptions.ensureIndex({ source_id: 1, source_type: 1 }, { background: true })
