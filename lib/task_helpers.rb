require 'elasticsearch'
require_relative '../models/comment'
require_relative '../models/comment_thread'

module TaskHelpers
  module ElasticsearchHelper
    LOG = Logger.new(STDERR)
    INDEX_MODELS = [Comment, CommentThread].freeze
    INDEX_NAMES = [Comment.index_name, CommentThread.index_name].freeze

    # Creates new indices and loads data from the database.
    #
    # Params:
    # +batch_size+:: (optional) The number of elements to index at a time. Defaults to 500.
    # +extra_catchup_minutes+:: (optional) The number of extra minutes to catchup. Defaults to 5.
    def self.rebuild_indices(batch_size=500, extra_catchup_minutes=5)
      initial_start_time = Time.now
      create_indices
      INDEX_MODELS.each do |model|
        current_batch = 1
        model.import(index: model.index_name, batch_size: batch_size) do |response|
            batch_import_post_process(response, current_batch)
            current_batch += 1
        end
      end

      adjusted_start_time = initial_start_time - extra_catchup_minutes * 60
      catchup_indices(adjusted_start_time, batch_size)

      LOG.info "Rebuild indices complete."
    end

    def self.catchup_indices(start_time, batch_size=100)
      INDEX_MODELS.each do |model|
        current_batch = 1
        model.where(:updated_at.gte => start_time).import(index: model.index_name, batch_size: batch_size) do |response|
            batch_import_post_process(response, current_batch)
            current_batch += 1
        end
      end
      LOG.info "Catch up from #{start_time} complete."
    end

    def self.create_indices
      INDEX_MODELS.each do |model|
        model.__elasticsearch__.create_index! force: true
      end
      LOG.info "New indices are created."
    end

    def self.delete_indices
      Elasticsearch::Model.client.indices.delete(index: INDEX_NAMES, ignore_unavailable: true)
      LOG.info "Indices are deleted."
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

    def self.exists_indices
      Elasticsearch::Model.client.indices.exists(index: INDEX_NAMES)
    end

    def self.refresh_indices
      Elasticsearch::Model.client.indices.refresh(index: INDEX_NAMES)
    end

    def self.initialize_indices(force_new_index)
      # When force_new_index is true, fresh indices will be created even if it already exists.
      if force_new_index or not exists_indices
        create_indices
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

      INDEX_MODELS.each do |model|
        expected_mapping = model.mappings.to_hash
        actual_mapping = actual_mappings[model.index_name]['mappings']
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
