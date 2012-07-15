module Mongoid
  module FeedStream
    module Followable
      extend ActiveSupport::Concern

      included do
        has_and_belongs_to_many :followers, class_name: self.name, inverse_of: :followings
        has_and_belongs_to_many :followings, class_name: self.name, inverse_of: :followers
      end

      def follow(user)
        if self.id != user.id and not self.following.include? user
          self.following << user
        end
      end

      def unfollow(user)
        self.following.delete(user)
      end
    end
  end
end
