require 'task_helpers'

def refresh_es_index
  TaskHelpers::ElasticsearchHelper.refresh_index(Content::ES_INDEX_NAME)
end


RSpec.shared_context 'search_enabled' do
  before(:all) do
    CommentService.config[:enable_search] = true
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
