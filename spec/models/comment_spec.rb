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

  it "should update its thread when endorsed changes" do
    comment = make_comment(author, thread, "dummy")
    orig_count = thread.endorsed_response_count
    comment.endorsed = true
    comment.save!
    thread.endorsed_response_count.should == orig_count + 1
    comment.endorsed = false
    comment.save!
    thread.endorsed_response_count.should == orig_count
  end
end
