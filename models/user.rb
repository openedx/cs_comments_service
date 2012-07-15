class User
  include Mongoid::Document
  include Mongo::Voter

  field :external_id, type: String
  
  has_many :comments
  has_many :comment_threads, inverse_of: :author
  has_many :activities, class_name: "Feed", inverse_of: :actor
  has_and_belongs_to_many :subscribed_feeds, class_name: "Feed", inverse_of: :subscribers
  has_and_belongs_to_many :followers, class_name: "User", inverse_of: :followings
  has_and_belongs_to_many :followings, class_name: "User", inverse_of: :followers

  attr_accessible :external_id

  validates_uniqueness_of :external_id
  validates_presence_of :external_id

  index :external_id, unique: true

  def follow(user)
    if self.id != user.id and not self.following.include? user
      self.following << user
    end
  end

  def unfollow(user)
    self.following.delete(user)
  end

  def self.watching(class_plural_sym)
    class_plural = class_plural_sym.to_s
    class_single = class_plural.singularize
    class_name = class_single.camelize
    watched_symbol = "watched_#{class_plural}".intern

    has_and_belongs_to_many watched_symbol, class_name: class_name, inverse_of: :watchers, autosave: true

    self.class_eval <<-END
      def watch_#{class_single}(watching_object)
        if not self.watched_#{class_plural}.include? watching_object
          self.watched_#{class_plural} << watching_object
        end
      end

      def unwatch_#{class_single}(watching_object)
        self.watched_#{class_plural}.delete(watching_object)
      end
    END
  end

  watching :comment_threads
  watching :commentables

end
