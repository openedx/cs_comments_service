var final_index_array = {
    'parent_id_1' : '{parent_id: 1}, { background: true }',
    'parent_ids_1' : '{parent_ids: 1}, { background: true }',
    'tags_array_1' : '{tags_array: 1}, { background: true }',
    'votes.up_1__type_1' : '{votes.up: 1, _type: 1}, { background: true }',
    'votes.down_1__type_1' : '{votes.down: 1, _type: 1}, { background: true }',
    'commentable_id_1_created_at_-1' : '{commentable_id: 1, created_at: -1}, { background: true }',
    'course_id_1__type_1_created_at_-1' : '{course_id: 1, _type: 1, created_at: -1}, { background: true }',
    '_type_1_comment_thread_id_1_author_id_1_updated_at_1' : '{_type: 1, comment_thread_id: 1, author_id: 1, updated_at: 1}, { background: true }',
    'comment_thread_id_1_sk_1' : '{comment_thread_id: 1, sk: 1}, { background: true , sparse: true}',
    'comment_thread_id_1_endorsed_1' : '{comment_thread_id: 1, endorsed: 1}, { background: true , sparse: true}',
    '_type_1_course_id_1_pinned_-1_created_at_-1' : '{_type: 1, course_id: 1, pinned: -1, created_at: -1}, { background: true }',
    '_type_1_course_id_1_pinned_-1_comment_count_-1_created_at_-1' : '{_type: 1, course_id: 1, pinned: -1, comment_count: -1, created_at: -1}, { background: true }',
    '_type_1_course_id_1_pinned_-1_votes.point_-1_created_at_-1' : '{_type: 1, course_id: 1, pinned: -1, votes.point: -1, created_at: -1}, { background: true }',
    'commentable_id_1' : '{commentable_id: 1}, { background: true , sparse: true}',
    '_type_1_course_id_1_context_1_pinned_-1_created_at_-1' : '{_type: 1, course_id: 1, context: 1, pinned: -1, created_at: -1}, { background: true }',
    '_type_1_context_1' : '{_type: 1, context: 1}, { background: true }',
    '_type_-1_course_id_1_context_1_pinned_-1_last_activity_at_-1_created_at_-1' : '{_type: -1, course_id: 1, context: 1, pinned: -1, last_activity_at: -1, created_at: -1}, { background: true }',
    '_type_-1_course_id_1_commentable_id_1_context_1_pinned_-1_created_at_-1' : '{_type: -1, course_id: 1, commentable_id: 1, context: 1, pinned: -1, created_at: -1}, { background: true }',
    '_type_-1_course_id_1_endorsed_-1_pinned_-1_last_activity_at_-1_created_at_-1' : '{_type: -1, course_id: 1, endorsed: -1, pinned: -1, last_activity_at: -1, created_at: -1}, { background: true }',
    '_type_-1_course_id_1_endorsed_-1_pinned_-1_votes.point_-1_created_at_-1' : '{_type: -1, course_id: 1, endorsed: -1, pinned: -1, votes.point: -1, created_at: -1}, { background: true }',
    '_type_-1_course_id_1_endorsed_-1_pinned_-1_comment_count_-1_created_at_-1' : '{_type: -1, course_id: 1, endorsed: -1, pinned: -1, comment_count: -1, created_at: -1}, { background: true }',
    'author_id_1_course_id_1' : '{author_id: 1, course_id: 1}, { background: true }'
};

print('Getting list of indexes...');
var json_of_indexes = db.contents.getIndexes(),
    json_of_indexes = JSON.parse(json);

var list_of_current_index_names = [];

for (index = 0; index < json_of_indexes.length; index++) { 
    list_of_current_index_names.push(index.name);
}

print('Current list of indexes:');
print(list_of_current_index_names);

print('Ensuring indexes...');
final_index_array.forEach(function(index_name)) {
    print('Ensuring'.concat(index));
    db.contents.ensureIndex(final_index_array[index_name]);
}

print('Dropping extra indexes');

final_index_array.forEach(function(index_name)) {
    if (list_of_current_index_names.indexOf(index_name > -1);
    print('Dropping'.concat(index));
    db.contents.dropIndex(index);
}

