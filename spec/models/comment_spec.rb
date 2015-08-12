require 'spec_helper'
require 'unicode_shared_examples'

describe Comment do
  let(:author) do
    create_test_user(42)
  end

  let(:course_thread) do
    make_thread(author, "Test course thread", "test_course", "test_commentable", :discussion, :course)
  end

  let(:standalone_thread) do
    make_thread(author, "Test standalone thread", "test_course", "test_commentable", :discussion, :standalone)
  end

  def test_unicode_data(text)
    comment = make_comment(author, course_thread, text)
    retrieved = Comment.find(comment._id)
    retrieved.body.should == text
  end

  include_examples "unicode data"

  describe '#context' do
    context 'with standalone_thread' do
      it 'returns "standalone"' do
        comment = make_comment(author, standalone_thread, "comment")
        expect(comment.context).to eq("standalone")
      end
    end

    context 'with course_thread' do
      it 'returns "course"' do
        comment = make_comment(author, course_thread, "comment")
        expect(comment.context).to eq("course")
      end
    end
  end

  describe '#course_context?' do
    context 'with standalone_thread' do
      it 'returns false' do
        comment = make_comment(author, standalone_thread, "comment")
        expect(comment.course_context?).to be_false
      end
    end

    context 'with course_thread' do
      it 'returns true' do
        comment = make_comment(author, course_thread, "comment")
        expect(comment.course_context?).to be_true
      end
    end
  end

  describe '#standalone_context?' do
    context 'with standalone_thread' do
      it 'returns true' do
        comment = make_comment(author, standalone_thread, "comment")
        expect(comment.standalone_context?).to be_true
      end
    end

    context 'with course_thread' do
      it 'returns false' do
        comment = make_comment(author, course_thread, "comment")
        expect(comment.standalone_context?).to be_false
      end
    end
  end
end
