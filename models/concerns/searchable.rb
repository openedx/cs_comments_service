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

    # Class-level variable which toggles all ES callbacks.  This should be an instance-level variable,
    # ideally, but it took us too long to get that working correctly.  This should be safe because forums
    # code runs single-threaded.
    @@enable_es = true

    # The caller may opt to temporarily disable ES callbacks by using this toggle, e.g.:
    #
    #   comment.enable_es(false)
    #   comment.update!(data)
    #   comment.enable_es(true)
    #
    def enable_es(x)
      @@enable_es = x
    end

    def is_es_enabled
      @@enable_es
    end

    private # all methods below are private

    def index_document
      __elasticsearch__.index_document if CommentService.search_enabled? && is_es_enabled
    end

    # This is named in this manner to prevent collisions with Mongoid's update_document method.
    def update_indexed_document
      begin
        __elasticsearch__.update_document if CommentService.search_enabled? && is_es_enabled
      rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
        # If attempting to update a document that doesn't exist, just continue.
        logger.warn "ES update failed upon update_document - not found."
      end
    end

    def delete_document
      begin
        __elasticsearch__.delete_document if CommentService.search_enabled? && is_es_enabled
      rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
        # If attempting to delete a document that doesn't exist, just continue.
        logger.warn "ES delete failed upon delete_document - not found."
      end
    end
  end
end
