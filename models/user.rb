class User
  include Mongoid::Document
  include Mongo::Voter
  field :external_id, type: String
  has_many :comments
end
