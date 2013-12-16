require 'spec_helper'
require 'unicode_shared_examples'

describe Comment do
  let(:author) do
    create_test_user(42)
  end

  let(:thread) do
    make_thread(author, "Test thread", "test_course", "test_commentable")
  end

  def test_unicode_data(text)
    comment = make_comment(author, thread, text)
    retrieved = Comment.find(comment._id)
    retrieved.body.should == text
  end

  include_examples "unicode data"
end
