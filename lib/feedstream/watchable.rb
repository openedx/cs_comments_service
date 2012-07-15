module Mongoid
  module FeedStream
    module Watchable
      extend ActiveSupport::Concern
      included do
        has_and_belongs_to_many :watchers, class_name: "User", inverse_of: "watched_#{self.name.underscore.pluralize}".intern
        
      end
    end
  end
end
