require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::WARN

module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model

    # We specify our own callbacks, instead of using Elasticsearch::Model::Callbacks, so that we can disable
    # indexing for tests where search functionality is not needed. This should improve test execution times.
    after_create :index_document
    after_update :update_indexed_document
    after_destroy :delete_document

    def as_indexed_json(options={})
      # TODO: Play with the `MyModel.indexes` method -- reject non-mapped attributes, `:as` options, etc
      self.as_json(options.merge root: false)
    end

    private # all methods below are private

    def index_document
      __elasticsearch__.index_document if CommentService.search_enabled?
    end

    # This is named in this manner to prevent collisions with Mongoid's update_document method.
    def update_indexed_document
      begin
        __elasticsearch__.update_document if CommentService.search_enabled?
      rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
        # If attempting to update a document that doesn't exist, just continue.
        logger.warn "ES update failed upon update_document - not found."
      end
    end

    def delete_document
      begin
        __elasticsearch__.delete_document if CommentService.search_enabled?
      rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
        # If attempting to delete a document that doesn't exist, just continue.
        logger.warn "ES delete failed upon delete_document - not found."
      end
    end
  end
end
