require 'task_helpers'

def refresh_es_index(index_name=nil)
  index_name = index_name ? index_name : Content::ES_INDEX_NAME
  TaskHelpers::ElasticsearchHelper.refresh_index(index_name)
end


RSpec.shared_context 'search_enabled' do

  before(:all) do
    CommentService.config[:enable_search] = true

    # Delete any previously created index to ensure our search tests start
    # with a clean slate. Each test will recreate the index.
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end

  after(:each) do
    # Delete the index after each test so it will be re-created.
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end

  after(:all) do
    # Ensure that subsequent tests, that do not require search, are unaffected by search.
    CommentService.config[:enable_search] = false

    # Ensure (once more) the index was deleted.
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end

end

RSpec.configure do |config|

  config.before(:suite) do
    CommentService.config[:enable_search] = false
  end

  config.before(:each) do
    # Create the index before each test if it doesn't exist.
    if not TaskHelpers::ElasticsearchHelper.exists_alias(Content::ES_INDEX_NAME)
      test_index = TaskHelpers::ElasticsearchHelper.create_index
      TaskHelpers::ElasticsearchHelper.move_alias(Content::ES_INDEX_NAME, test_index)
    end
  end

  config.after(:suite) do
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end

end
