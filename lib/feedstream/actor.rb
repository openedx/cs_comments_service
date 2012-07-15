module Mongoid
  module FeedStream
    module Actor
      extend ActiveSupport::Concern
      included do
        has_many :activities, class_name: "Feed", inverse_of: :actor, autosave: true
      end
    end
  end
end
