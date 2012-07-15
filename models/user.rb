class User
  include Mongoid::Document
  include Mongo::Voter
  include Mongoid::Watcher
  include Mongoid::Followable

  field :external_id, type: String
  
  watching :comment_threads
  watching :commentables

  has_many :comments
  has_many :comment_threads, inverse_of: :author

  attr_accessible :external_id

  validates_uniqueness_of :external_id
  validates_presence_of :external_id

  index :external_id, unique: true

end
