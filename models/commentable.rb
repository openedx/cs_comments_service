class Commentable
  include Mongoid::Document
  include Mongoid::Watchable 

  field :commentable_type, type: String
  field :commentable_id, type: String

  has_many :comment_threads, dependent: :destroy

  attr_accessible :commentable_type, :commentable_id

  validates_presence_of :commentable_type
  validates_presence_of :commentable_id
  validates_uniqueness_of :commentable_id, scope: :commentable_type

  index [:commentable_type, :commentable_id]

  def to_hash
    as_document
  end

end
