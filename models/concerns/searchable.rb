module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model

    # We specify our own callbacks, instead of using Elasticsearch::Model::Callbacks, so that we can disable
    # indexing for tests where search functionality is not needed. This should improve test execution times.
    after_create :index_document
    after_update :update_indexed_document
    after_destroy :delete_document

    def self.put_search_index_mapping(index=nil)
      index ||= self.index_name
      success = self.__elasticsearch__.client.indices.put_mapping(index: index, type: self.document_type, body: self.mappings.to_hash)
      unless success
        logger.warn "WARNING! could not apply search index mapping for #{self.name}"
      end
    end

    def as_indexed_json(options={})
      # TODO: Play with the `MyModel.indexes` method -- reject non-mapped attributes, `:as` options, etc
      self.as_json(options.merge root: false)
    end

    private
    def index_document
      __elasticsearch__.index_document if CommentService.search_enabled?
    end

    # This is named in this manner to prevent collisions with Mongoid's update_document method.
    def update_indexed_document
      __elasticsearch__.update_document if CommentService.search_enabled?
    end

    def delete_document
      __elasticsearch__.delete_document if CommentService.search_enabled?
    end
  end
end
