db.users.dropIndex({ external_id: 1 }) // drop the unique one
db.users.ensureIndex({ external_id: 1 }, { background: true })
db.subscriptions.dropIndex({ source_id: 1, source_type: 1 })
