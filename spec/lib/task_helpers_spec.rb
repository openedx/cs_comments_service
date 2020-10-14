require 'spec_helper'
require 'elasticsearch'

describe TaskHelpers do
  describe TaskHelpers::ElasticsearchHelper do
  let(:alias_name) { 'test_alias' }

    before(:each) do
      TaskHelpers::ElasticsearchHelper.delete_indices
      TaskHelpers::ElasticsearchHelper.rebuild_indices
    end

    def assert_alias_points_to_index(alias_name, index_name)
      test_alias = Elasticsearch::Model.client.indices.get_alias(name: alias_name).keys[0]
      test_alias.should == index_name
    end

    context("#move_alias") do
      before(:each) do
        @index_names = TaskHelpers::ElasticsearchHelper.create_indices
        @index_name = @index_names[0]
      end

      after(:each) do
        Elasticsearch::Model.client.indices.delete(index: @index_names, ignore_unavailable: true)
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

    end

    context("#rebuild_indices") do
      include_context 'search_enabled'

      it "builds new index with content" do
        create(:comment_thread, body: 'the best test body', course_id: 'test_course_id')
        TaskHelpers::ElasticsearchHelper.refresh_indices
        Elasticsearch::Model.client.search(
            index: TaskHelpers::ElasticsearchHelper::INDEX_NAMES
        )['hits']['total']['value'].should be > 0
      end

    end

    context("#validate_indices") do
      subject { TaskHelpers::ElasticsearchHelper.validate_indices}

      it "validates the 'content' alias exists with proper mappings" do
        subject
      end

      it "fails if one of the index doesn't exist" do
        Elasticsearch::Model.client.indices.delete(index: TaskHelpers::ElasticsearchHelper::temporary_index_names[0])
        expect{subject}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
        Elasticsearch::Model.client.indices.delete(index: TaskHelpers::ElasticsearchHelper::temporary_index_names[1])
      end

    end

  end
end
