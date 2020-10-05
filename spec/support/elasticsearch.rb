require 'task_helpers'


RSpec.shared_context 'search_enabled' do

  before(:all) do
    CommentService.config[:enable_search] = true

    # Delete any previously created index to ensure our search tests start
    # with a clean slate. Each test will recreate the index.
    TaskHelpers::ElasticsearchHelper.delete_indices
  end

  after(:each) do
    # Delete the index after each test so it will be re-created.
    TaskHelpers::ElasticsearchHelper.delete_indices
  end

  after(:all) do
    # Ensure that subsequent tests, that do not require search, are unaffected by search.
    CommentService.config[:enable_search] = false

    # Ensure (once more) the index was deleted.
    TaskHelpers::ElasticsearchHelper.delete_indices
  end

end

RSpec.configure do |config|

  config.before(:suite) do
    CommentService.config[:enable_search] = false
  end

  config.before(:each) do
    # Create the index before each test if it doesn't exist.
    TaskHelpers::ElasticsearchHelper.initialize_indices
  end

  config.after(:suite) do
    TaskHelpers::ElasticsearchHelper.delete_indices
  end

end
