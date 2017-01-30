require 'spec_helper'
require 'elasticsearch'

describe TaskHelpers do
  describe TaskHelpers::ElasticsearchHelper do
    let(:alias_name) { 'test_alias' }

    after(:each) do
      TaskHelpers::ElasticsearchHelper.delete_index(alias_name)
    end

    def assert_alias_points_to_index(alias_name, index_name)
      test_alias = Elasticsearch::Model.client.indices.get_alias(name: alias_name).keys[0]
      test_alias.should == index_name
    end

    context("#move_alias") do
      before(:each) do
        @index_name = TaskHelpers::ElasticsearchHelper.create_index()
      end

      after(:each) do
        TaskHelpers::ElasticsearchHelper.delete_index(@index_name)
      end

      it "points alias to index" do
        TaskHelpers::ElasticsearchHelper.move_alias(alias_name, @index_name)
        assert_alias_points_to_index(alias_name, @index_name)
      end

      it "fails when alias is same as index_name" do
        expect { TaskHelpers::ElasticsearchHelper.move_alias(@index_name, @index_name) }.to raise_error
      end

      it "fails when index doesn't exist" do
        expect { TaskHelpers::ElasticsearchHelper.move_alias(alias_name, 'missing_index') }.to raise_error
      end

      it "fails when index of same name as alias exists" do
        TaskHelpers::ElasticsearchHelper.create_index(alias_name)
        expect { TaskHelpers::ElasticsearchHelper.move_alias(alias_name, @index_name) }.to raise_error
      end

      it "points alias to index when index of same name as alias is deleted" do
        TaskHelpers::ElasticsearchHelper.create_index(alias_name)
        force_delete = true
        TaskHelpers::ElasticsearchHelper.move_alias(alias_name, @index_name, force_delete)
        assert_alias_points_to_index(alias_name, @index_name)
      end

    end

    context("#rebuild_index") do
      include_context 'search_enabled'

      def create_thread_and_delete_index()
        thread = create(:comment_thread, body: 'the best test body', course_id: 'test_course_id')
        refresh_es_index
        TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
      end

      it "builds new index without switching alias" do
        create_thread_and_delete_index

        index_name = TaskHelpers::ElasticsearchHelper.rebuild_index()
        refresh_es_index(index_name)

        Elasticsearch::Model.client.search(index: index_name)['hits']['total'].should be > 0
      end

      it "builds new index and points alias to it" do
        create_thread_and_delete_index

        index_name = TaskHelpers::ElasticsearchHelper.rebuild_index(alias_name)
        refresh_es_index(alias_name)

        Elasticsearch::Model.client.search(index: alias_name)['hits']['total'].should be > 0
      end

      it "builds new index and points alias to it, first deleting index with same name as alias" do
        create_thread_and_delete_index
        TaskHelpers::ElasticsearchHelper.create_index(alias_name)

        index_name = TaskHelpers::ElasticsearchHelper.rebuild_index(alias_name)
        refresh_es_index(alias_name)

        Elasticsearch::Model.client.search(index: alias_name)['hits']['total'].should be > 0
      end
    end

    context("#validate_index") do
      include_context 'search_enabled'

      subject { TaskHelpers::ElasticsearchHelper.validate_index(Content::ES_INDEX_NAME) }

      it "validates the 'content' alias exists with proper mappings" do
        subject
      end

      it "fails if the alias doesn't exist" do
        TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
        expect{subject}.to raise_error(RuntimeError)
      end

      it "fails if the alias has the wrong mappings" do
        Elasticsearch::Model.client.indices.delete_mapping(index: Content::ES_INDEX_NAME, type: Comment.document_type)
        expect{subject}.to raise_error(RuntimeError)
      end
    end

  end
end
