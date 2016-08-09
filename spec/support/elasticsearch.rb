def delete_es_index
  Tire.index Content::ES_INDEX_NAME do
    delete
  end
end

def create_es_index
  new_index = Tire.index Content::ES_INDEX_NAME
  new_index.create
  [CommentThread, Comment].each do |klass|
    klass.put_search_index_mapping
  end
end

def refresh_es_index
  es_index_name = Content::ES_INDEX_NAME
  Tire.index es_index_name do
    refresh
  end
end

RSpec.configure do |config|
  config.before(:each) do
    delete_es_index
    create_es_index
  end
end
