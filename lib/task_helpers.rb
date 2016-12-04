require 'elasticsearch'

module TaskHelpers
  module ElasticsearchHelper
    LOG = Logger.new(STDERR)

    def self.create_index(name=nil)
      name ||= "#{Content::ES_INDEX_NAME}_#{Time.now.strftime('%Y%m%d%H%M%S')}"

      mappings = {}
      [Comment, CommentThread].each do |model|
        mappings.merge! model.mappings.to_hash
      end

      Elasticsearch::Model.client.indices.create(index: name, body: {mappings: mappings})
      LOG.info "Created new index: #{name}."
      name
    end

    def self.delete_index(name)
      begin
        Elasticsearch::Model.client.indices.delete(index: name)
        LOG.info "Deleted index: #{name}."
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        # NOTE (CCB): Future versions of the Elasticsearch client support the ignore parameter,
        # that can be used to ignore 404 errors.
        LOG.info "Unable to delete non-existent index: #{name}."
      end
    end

    def self.get_index_shard_count(name)
      settings = Elasticsearch::Model.client.indices.get_settings(index: name)
      settings[name]['settings']['index']['number_of_shards']
    end

    def self.move_alias(alias_name, index_name)
      actions = [
          {add: {index: index_name, alias: alias_name}}
      ]

      begin
        response = Elasticsearch::Model.client.indices.get_alias(name: alias_name)
        if response.length
          actions.unshift({remove: {index: response.keys.join(','), alias: alias_name}})
        end
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        # NOTE (CCB): Future versions of the Elasticsearch client support the ignore parameter,
        # that can be used to ignore 404 errors.
      end

      body = {actions: actions}
      Elasticsearch::Model.client.indices.update_aliases(body: body)
      LOG.info "Alias [#{alias_name}] now points to index [#{index_name}]."
    end

    def self.refresh_index(name)
      Elasticsearch::Model.client.indices.refresh(index: name)
    end
  end
end
