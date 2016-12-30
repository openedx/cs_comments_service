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

      it "builds new index" do
        index_name = TaskHelpers::ElasticsearchHelper.rebuild_index()
        TaskHelpers::ElasticsearchHelper.exists_index(index_name).should be_true
      end

      it "builds new index and points alias to it when index of same name as alias exists" do
        TaskHelpers::ElasticsearchHelper.create_index(alias_name)
        index_name = TaskHelpers::ElasticsearchHelper.rebuild_index(alias_name)
        assert_alias_points_to_index(alias_name, index_name)
      end

    end
  end
end