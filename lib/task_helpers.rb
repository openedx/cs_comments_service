require 'elasticsearch'
require_relative '../models/comment'
require_relative '../models/comment_thread'

module TaskHelpers
  module ElasticsearchHelper
    LOG = Logger.new(STDERR)
    INDEX_MODELS = [Comment, CommentThread].freeze
    INDEX_NAMES = [Comment.index_name, CommentThread.index_name].freeze
    # local variable which store actual indices for future deletion
    @@temporary_index_names = []

    def self.temporary_index_names
      @@temporary_index_names
    end

    def self.add_temporary_index_names(index_names)
      # clone list of new index names which have been already created
      @@temporary_index_names = index_names
    end

    # Creates new indices and loads data from the database.
    #
    # Params:
    # +batch_size+:: (optional) The number of elements to index at a time. Defaults to 500.
    # +extra_catchup_minutes+:: (optional) The number of extra minutes to catchup. Defaults to 5.
    def self.rebuild_indices(batch_size=500, extra_catchup_minutes=5)
      initial_start_time = Time.now

      index_names = create_indices
      index_names.each do |index_name|
        current_batch = 1
        model = get_index_model_rel(index_name)
        model.import(index: index_name, batch_size: batch_size) do |response|
          batch_import_post_process(response, current_batch)
          current_batch += 1
        end
      end

      # Just in case initial rebuild took days and first catch up takes hours,
      # we catch up once before the alias move and once afterwards.
      first_catchup_start_time = Time.now
      adjusted_start_time = initial_start_time - (extra_catchup_minutes * 60)
      catchup_indices(index_names, adjusted_start_time, batch_size)

      alias_names = []
      index_names.each do |index_name|
        current_batch = 1
        model = get_index_model_rel(index_name)
        model_index_name = model.index_name
        alias_names.push(model_index_name)
        move_alias(model_index_name, index_name, force_delete: true)
      end

      adjusted_start_time = first_catchup_start_time - (extra_catchup_minutes * 60)
      catchup_indices(alias_names, adjusted_start_time, batch_size)

      add_temporary_index_names(index_names)
      LOG.info "Rebuild indices complete."
    end

    # Get index name which corresponds to the model
    def self.get_index_model_rel(index_name)
      model = nil
      if index_name.include? Comment.index_name
        model = Comment
      elsif index_name.include? CommentThread.index_name
        model = CommentThread
      end
      model
    end

    def self.catchup_indices(index_names, start_time, batch_size=100)
      index_names.each do |index_name|
        current_batch = 1
        model = get_index_model_rel(index_name)
        model.where(:updated_at.gte => start_time).import(index: index_name, batch_size: batch_size) do |response|
          batch_import_post_process(response, current_batch)
          current_batch += 1
        end
      end
      LOG.info "Catch up from #{start_time} complete."
    end

    def self.create_indices
      index_names = []
      time_now = Time.now.strftime('%Y%m%d%H%M%S%L')

      INDEX_MODELS.each do |model|
        index_name = "#{model.index_name}_#{time_now}"
        index_names.push(index_name)
        Elasticsearch::Model.client.indices.create(
          index: index_name,
          body: {"mappings": model.mapping.to_hash}
        )
      end
      LOG.info "New indices #{index_names} are created."
      index_names
    end

    def self.delete_index(name)
      Elasticsearch::Model.client.indices.delete(index: name, ignore_unavailable: true)
      LOG.info "Deleted index: #{name}."
    end

    # Deletes current indices if they used by forum app
    def self.delete_indices
      # NOTE: elasticsearch cannot delete index by alias, so forum store names
      # of current indices in the temporary_index_names variable. If it is empty
      # forum indices cannot be deleted by forum
      if temporary_index_names.length > 0
        Elasticsearch::Model.client.indices.delete(index: temporary_index_names, ignore_unavailable: true)
        LOG.info "Indices #{temporary_index_names} are deleted."
      else
        LOG.info "No Indices to delete."
      end
    end

    def self.batch_import_post_process(response, batch_number)
      response['items'].select { |i| i['index']['error'] }.each do |item|
          LOG.error "Error indexing. Response was: #{response}"
      end
      LOG.info "Imported batch #{batch_number} into the index"
    end

    def self.get_index_shard_count(name)
      settings = Elasticsearch::Model.client.indices.get_settings(index: name)
      settings[name]['settings']['index']['number_of_shards']
    end

    def self.exists_alias(alias_name)
      Elasticsearch::Model.client.indices.exists_alias(name: alias_name)
    end

    def self.exists_indices
      Elasticsearch::Model.client.indices.exists(index: temporary_index_names)
    end

    def self.exists_aliases(aliases)
      Elasticsearch::Model.client.indices.exists_alias(name: aliases)
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

    def self.refresh_indices
      if temporary_index_names.length > 0
        Elasticsearch::Model.client.indices.refresh(index: INDEX_NAMES)
      else
        fail "No indices to refresh"
      end
    end

    def self.initialize_indices(force_new_index = false)
      # When force_new_index is true, fresh indices will be created even if it already exists.
      if force_new_index or not exists_aliases(INDEX_NAMES)
        index_names = create_indices
        index_names.each do |index_name|
          model = get_index_model_rel(index_name)
          move_alias(model.index_name, index_name, force_delete: true)
        end
        add_temporary_index_names(index_names)
      else
        LOG.info "Skipping initialization. Indices already exist. If 'rake search:validate_indices' indicates "\
          "a problem with the mappings, you could either use 'rake search:rebuild_indices' to reload from the db or 'rake "\
          "search:initialize[true]' to force initialization with an empty index."
      end
    end

    # Validates that each index includes the proper mappings.
    # There is no return value, but an exception is raised if the index is invalid.
    def self.validate_indices
      actual_mappings = Elasticsearch::Model.client.indices.get_mapping(index: INDEX_NAMES)

      if actual_mappings.length == 0
        fail "Indices are not exist!"
      end

      actual_mappings.keys.each do |index_name|
        model = get_index_model_rel(index_name)
        expected_mapping = model.mappings.to_hash
        actual_mapping = actual_mappings[index_name]['mappings']
        expected_mapping_keys = expected_mapping.keys.map { |x| x.to_s }
        if actual_mapping.keys != expected_mapping_keys
          fail "Actual mapping [#{actual_mapping.keys}] does not match expected mapping (including order) [#{expected_mapping.keys}]."
        end

        actual_mapping_properties = actual_mapping['properties']
        expected_mapping_properties = expected_mapping[:properties]
        missing_fields = Array.new
        invalid_field_types = Array.new

        expected_mapping_properties.keys.each do |property|
          if actual_mapping_properties.key?(property.to_s)
            expected_type = expected_mapping_properties[property][:type].to_s
            actual_type = actual_mapping_properties[property.to_s]['type']
            if actual_type != expected_type
              invalid_field_types.push("'#{property}' type '#{actual_type}' should be '#{expected_type}'")
            end
          else
            missing_fields.push(property)
          end
        end
        if missing_fields.any? or invalid_field_types.any?
          fail "Index '#{model.index_name}' has missing or invalid field mappings.  Missing fields: #{missing_fields}. Invalid types: #{invalid_field_types}."
        end

        # Check that expected field mappings of the correct type exist
        LOG.info "Passed: Index '#{model.index_name}' exists with up-to-date mappings."
      end

    end

  end
end
