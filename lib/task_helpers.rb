module TaskHelpers
  module ElasticsearchHelper
    def self.create_index(name=nil)
      name ||= "#{Content::ES_INDEX_NAME}_#{Time.now.strftime('%Y%m%d%H%M%S')}"
      index = Tire.index(name)

      LOG.info "Creating new index: #{name}..."
      index.create

      [CommentThread, Comment].each do |model|
        LOG.info "Applying index mappings for #{model.name}"
        model.put_search_index_mapping(index)
      end
      LOG.info '...done!'

      index
    end

    def self.delete_index(name)
      Tire.index(name).delete
    end

    def self.get_index
      CommentThread.tire.index
    end

    def self.get_index_shard_count(name)
      settings = Tire.index(name)
      settings['index.number_of_shards']
    end
  end
end
