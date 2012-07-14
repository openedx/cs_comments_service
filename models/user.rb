class User
  include Mongoid::Document
  include Mongo::Voter

  field :external_id, type: String

  has_many :comments
  has_many :commentable

  attr_accessible :external_id

  validates_uniqueness_of :external_id
  validates_presence_of :external_id

  index :external_id, unique: true

end
