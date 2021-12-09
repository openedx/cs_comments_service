
class EditHistory
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :original_body, type: String
  field :reason_code, type: String

  belongs_to :author, class_name: 'User', inverse_of: :comment_edits

  embedded_in :comment
end
