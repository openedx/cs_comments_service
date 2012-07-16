class User
  include Mongoid::Document
  include Mongo::Voter

  key :external_id, type: String, index: true
  
  has_many :comments
  has_many :comment_threads, inverse_of: :author
  has_many :activities, class_name: "Notification", inverse_of: :actor
  has_and_belongs_to_many :notifications, inverse_of: :receivers
  has_and_belongs_to_many :followers, class_name: "User", inverse_of: :followings, autosave: true
  has_and_belongs_to_many :followings, class_name: "User", inverse_of: :followers

  validates_presence_of :external_id
  validates_uniqueness_of :external_id

  def to_hash(params={})
    as_document.slice(*%w[_id external_id])
  end

  def follow(user)
    if id != user.id and not followings.include? user
      followings << user
    end
  end

  def unfollow(user)
    followings.delete(user)
  end

  def self.subscribing(class_plural_sym)
    class_plural = class_plural_sym.to_s
    class_single = class_plural.singularize
    class_name = class_single.camelize
    subscribed_symbol = "subscribed_#{class_plural}".intern

    has_and_belongs_to_many subscribed_symbol, class_name: class_name, inverse_of: :subscribers

    self.class_eval <<-END
      def subscribe_#{class_single}(subscribing_object)
        if not subscribed_#{class_plural}.include? subscribing_object
          subscribed_#{class_plural} << subscribing_object
        end
      end

      def unsubscribe_#{class_single}(subscribing_object)
        subscribed_#{class_plural}.delete(subscribing_object)
      end
    END
  end

  subscribing :comment_threads
  subscribing :commentables

end
