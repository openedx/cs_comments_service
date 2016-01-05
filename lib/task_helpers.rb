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
    # +batch_size+:: (optional) The number of elements to index at a time. Defaults to 500.
    # +sleep_time+:: (optional) The number of seconds to sleep between batches. Defaults to 0.
    # +extra_catchup_minutes+:: (optional) The number of extra minutes to catchup. Defaults to 5.
    def self.rebuild_index(alias_name=nil, batch_size=500, sleep_time=0, extra_catchup_minutes=5)
      initial_start_time = Time.now
      index_name = create_index()

      [Comment, CommentThread].each do |model|
        current_batch = 1
        model.import(index: index_name, batch_size: batch_size) do |response|
            batch_import_post_process(response, current_batch, sleep_time)
            current_batch += 1
        end
      end

      if alias_name
        # Just in case initial rebuild took days and first catch up takes hours,
        # we catch up once before the alias move and once afterwards.
        first_catchup_start_time = Time.now
        adjusted_start_time = initial_start_time - (extra_catchup_minutes * 60)
        catchup_index(adjusted_start_time, index_name, batch_size, sleep_time)

        move_alias(alias_name, index_name, force_delete: true)
        adjusted_start_time = first_catchup_start_time - (extra_catchup_minutes * 60)
        catchup_index(adjusted_start_time, alias_name, batch_size, sleep_time)
      end

      LOG.info "Rebuild index complete."
      index_name
    end

    def self.catchup_index(start_time, index_name, batch_size=100, sleep_time=0)
      [Comment, CommentThread].each do |model|
        current_batch = 1
        model.where(:updated_at.gte => start_time).import(index: index_name, batch_size: batch_size) do |response|
            batch_import_post_process(response, current_batch, sleep_time)
            current_batch += 1
        end
      end
      LOG.info "Catch up from #{start_time} complete."
    end

    def self.create_index(name=nil)
      name ||= "#{Content::ES_INDEX_NAME}_#{Time.now.strftime('%Y%m%d%H%M%S%L')}"

      Elasticsearch::Model.client.indices.create(index: name)
      put_mappings(name)

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

    def self.batch_import_post_process(response, batch_number, sleep_time)
        response['items'].select { |i| i['index']['error'] }.each do |item|
            LOG.error "Error indexing. Response was: #{response}"
        end
        LOG.info "Imported batch #{batch_number} into the index"
        sleep(sleep_time)
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

    def self.initialize_index(alias_name, force_new_index)
      # When force_new_index is true, a fresh index will be created for the alias,
      # even if it already exists.
      if force_new_index or not exists_alias(alias_name)
        index_name = create_index()
        # WARNING: if an index exists with the same name as the intended alias, it
        #   will be deleted.
        move_alias(alias_name, index_name, force_delete: true)
      else
        LOG.info "Skipping initialization. The 'content' alias already exists. If 'rake search:validate_index' indicates "\
          "a problem with the mappings, you could either use 'rake search:rebuild_index' to reload from the db or 'rake "\
          "search:initialize[true]' to force initialization with an empty index."
      end
    end

    def self.put_mappings(name)
      # As of ES 0.9, the order that these mappings are created matters.  Unit test failures
      # appear with a different order. It is unclear if this is a defect in ES, the test, or
      # neither.
      [CommentThread, Comment].each do |model|
        Elasticsearch::Model.client.indices.put_mapping(index: name, type: model.document_type, body: model.mappings.to_hash)
      end
      LOG.info "Added mappings to index: #{name}."
    end

    # Validates that the alias exists and its index includes the proper mappings.
    # There is no return value, but an exception is raised if the alias is invalid.
    #
    # Params:
    # +alias_name+:: The alias name to be validated.
    def self.validate_index(alias_name)
      if exists_alias(alias_name) === false
        fail "Alias '#{alias_name}' does not exist."
      end

      actual_mapping = Elasticsearch::Model.client.indices.get_mapping(index: alias_name).values[0]['mappings']
      expected_mapping = {}
      [CommentThread, Comment].each do |model|
        expected_mapping.merge! model.mappings.to_hash
      end

      # As of ES 0.9, the order the mappings are created in matters.  See put_mappings.
      # Compare document types and order
      expected_mapping_keys = expected_mapping.keys.map { |x| x.to_s }
      if actual_mapping.keys != expected_mapping_keys
        fail "Actual mapping types [#{actual_mapping.keys}] does not match expected mapping types (including order) [#{expected_mapping.keys}]."
      end

      # Check that expected field mappings of the correct type exist
      expected_mapping.keys.each do |doc_type|
        missing_fields = Array.new
        invalid_field_types = Array.new
        expected_mapping[doc_type][:properties].keys.each do |property|
          if actual_mapping[doc_type.to_s]['properties'].key?(property.to_s)
            expected_type = expected_mapping[doc_type][:properties][property][:type].to_s
            actual_type = actual_mapping[doc_type.to_s]['properties'][property.to_s]['type']
            if actual_type != expected_type
              invalid_field_types.push("'#{property}' type '#{actual_type}' should be '#{expected_type}'")
            end
          else
            missing_fields.push(property)
          end
        end
        if missing_fields.any? or invalid_field_types.any?
          fail "Document type '#{doc_type}' has missing or invalid field mappings.  Missing fields: #{missing_fields}. Invalid types: #{invalid_field_types}."
        end
      end
      LOG.info "Passed: Alias '#{alias_name}' exists with up-to-date mappings."
    end

  end
end
