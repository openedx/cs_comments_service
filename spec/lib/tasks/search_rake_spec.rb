require 'spec_helper'
require 'elasticsearch'

describe "search:rebuild_index" do
  include_context "rake"
  include_context 'search_enabled'

  its(:prerequisites) { should include("environment") }

  def create_thread_and_delete_index()
    thread = create(:comment_thread, body: 'the best test body', course_id: 'test_course_id')
    refresh_es_index
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end

  # Returns newest created index by comparing current against array of indices_before.
  # Has side effects of asserting there is 1 new index and refreshing this newest index.
  def get_newest_index_name(indices_before)
    indices_after = Elasticsearch::Model.client.indices.get_aliases.keys
    new_indices = indices_after - indices_before
    new_indices.length.should eq 1
    index_name = new_indices[0]
    refresh_es_index(index_name)
    index_name
  end

  it "builds new index without switching alias" do
    create_thread_and_delete_index
    indices_before = Elasticsearch::Model.client.indices.get_aliases.keys

    subject.invoke

    index_name = get_newest_index_name(indices_before)
    index_name.should_not eq Content::ES_INDEX_NAME
    Elasticsearch::Model.client.search(index: index_name)['hits']['total'].should be > 0
  end

  it "builds new index and points alias to it, first deleting index with same name as alias" do
    create_thread_and_delete_index
    TaskHelpers::ElasticsearchHelper.create_index(Content::ES_INDEX_NAME)
    call_move_alias = true

    subject.invoke(call_move_alias)
    refresh_es_index

    Elasticsearch::Model.client.search(index: Content::ES_INDEX_NAME)['hits']['total'].should be > 0
  end

end