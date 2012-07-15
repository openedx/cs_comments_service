class Commentable
  include Mongoid::Document

  field :commentable_type, type: String
  field :commentable_id, type: String

  has_many :comment_threads, dependent: :destroy
  has_and_belongs_to_many :watchers, class_name: "User", inverse_of: :watched_commentables

  attr_accessible :commentable_type, :commentable_id

  validates_presence_of :commentable_type
  validates_presence_of :commentable_id
  validates_uniqueness_of :commentable_id, scope: :commentable_type

  index [[:commentable_type, Mongo::ASCENDING], [:commentable_id, Mongo::ASCENDING]]

  def to_hash(params={})
    as_document.slice(*%w[_id commentable_type commentable_id])
  end

end
