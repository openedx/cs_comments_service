require 'task_helpers'

def refresh_es_index
  TaskHelpers::ElasticsearchHelper.refresh_index(Content::ES_INDEX_NAME)
end


RSpec.shared_context 'search_enabled' do
  before(:all) do
    CommentService.config[:enable_search] = true

    # Delete any indices that might have been previously-created to ensure our search
    # tests start with a clean slate. Each test will recreate the index.
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end

  before(:each) do
    index = TaskHelpers::ElasticsearchHelper.create_index
    TaskHelpers::ElasticsearchHelper.move_alias(Content::ES_INDEX_NAME, index)
  end

  after(:each) do
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    CommentService.config[:enable_search] = false
  end
end
