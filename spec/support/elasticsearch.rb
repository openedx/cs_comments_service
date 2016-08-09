require 'task_helpers'

def refresh_es_index
  TaskHelpers::ElasticsearchHelper.refresh_index(Content::ES_INDEX_NAME)
end


RSpec.shared_context 'search_enabled' do
  before(:all) do
    CommentService.config[:enable_search] = true
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end

  before(:each) do
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
    index = TaskHelpers::ElasticsearchHelper.create_index
    TaskHelpers::ElasticsearchHelper.move_alias(Content::ES_INDEX_NAME, index)
  end

  after(:all) do
    TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    CommentService.config[:enable_search] = false
  end
end
