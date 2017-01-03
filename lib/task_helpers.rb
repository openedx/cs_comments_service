require 'elasticsearch'

module TaskHelpers
  module ElasticsearchHelper
    LOG = Logger.new(STDERR)

    # Creates a new index and loads data from the database.  If an alias name
    # is supplied, it will be pointed to the new index and catch up will be
    # called both before and after the alias switch..
    #
    # Returns the name of the newly created index.
    #
    # Params:
    # +alias_name+:: (optional) The alias to point to the new index.
    def self.rebuild_index(alias_name=nil)
      initial_start_time = Time.now
      index_name = create_index()

      [Comment, CommentThread].each do |model|
        model.import(index: index_name)
      end

      if alias_name
        # Just in case initial rebuild took days and first catch up takes hours,
        # we catch up once before the alias move and once afterwards.
        first_catchup_start_time = Time.now
        catchup_index(initial_start_time, index_name)

        move_alias(alias_name, index_name, force_delete: true)
        catchup_index(first_catchup_start_time, alias_name)
      end

      index_name
    end

    def self.catchup_index(start_time, index_name)
      [Comment, CommentThread].each do |model|
        model.where(:updated_at.gte => start_time).import(index: index_name)
      end
    end

    def self.create_index(name=nil)
      name ||= "#{Content::ES_INDEX_NAME}_#{Time.now.strftime('%Y%m%d%H%M%S%L')}"

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

    def self.exists_alias(alias_name)
      Elasticsearch::Model.client.indices.exists_alias(name: alias_name)
    end

    def self.exists_index(index_name)
      Elasticsearch::Model.client.indices.exists(index: index_name)
    end

    def self.move_alias(alias_name, index_name, force_delete=false)
      unless index_name != alias_name
        raise ArgumentError, "Can't point alias [#{alias_name}] to an index of the same name."
      end
      unless exists_index(index_name)
        raise ArgumentError, "Can't point alias to non-existent index [#{index_name}]."
      end

      # You cannot use an alias name if an index of the same name (that is not an alias) already exists.
      # This could happen if the index was auto-created before the alias was properly set up.  In this
      # case, we either warn the user or delete the already existing index.
      if exists_index(alias_name) and not exists_alias(alias_name)
        if force_delete
          self.delete_index(alias_name)
        else
          raise ArgumentError, "Can't create alias [#{alias_name}] because there is already an " +
              "auto-generated index of the same name. Try again with force_delete=true to first " +
              "delete this pre-existing index."
        end
      end

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
