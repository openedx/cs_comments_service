
class EditHistory
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :original_body, type: String
  field :reason_code, type: String
  field :editor_username, type: String

  belongs_to :author, class_name: 'User', inverse_of: :comment_edits

  embedded_in :comment
  def to_hash
    as_document.slice(ORIGINAL_BODY, REASON_CODE, "editor_username", CREATED_AT)
  end
end
