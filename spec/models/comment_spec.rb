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

    context 'without valid parent thread' do
      it 'returns nil' do
        comment = make_comment(author, course_thread, "comment")
        comment.comment_thread_id = 'not a thread'
        expect(comment.context).to eq(nil)
      end
    end
  end

  describe '#course_context?' do
    context 'with standalone_thread' do
      it 'returns false' do
        comment = make_comment(author, standalone_thread, "comment")
        expect(comment.course_context?).to be false
      end
    end

    context 'with course_thread' do
      it 'returns true' do
        comment = make_comment(author, course_thread, "comment")
        expect(comment.course_context?).to be true
      end
    end

    context 'without valid parent thread' do
      it 'returns false' do
        comment = make_comment(author, course_thread, "comment")
        comment.comment_thread_id = 'not a thread'
        expect(comment.course_context?).to be false
      end
    end
  end

  describe '#standalone_context?' do
    context 'with standalone_thread' do
      it 'returns true' do
        comment = make_comment(author, standalone_thread, "comment")
        expect(comment.standalone_context?).to be true
      end
    end

    context 'with course_thread' do
      it 'returns false' do
        comment = make_comment(author, course_thread, "comment")
        expect(comment.standalone_context?).to be false
      end
    end

    context 'without valid parent thread' do
      it 'returns false' do
        comment = make_comment(author, course_thread, "comment")
        comment.comment_thread_id = 'not a thread'
        expect(comment.standalone_context?).to be false
      end
    end

  end

  describe '#child_count' do
    context 'with course_thread' do
      it 'returns cached child count' do
        comment = make_comment(author, course_thread, "comment")
        child_comment = make_comment(author, comment, "comment")
        expect(comment.get_cached_child_count).to eq(1)
      end

      it 'returns cached child count' do
        comment = make_comment(author, course_thread, "comment")
        child_comment = make_comment(author, comment, "comment")
        comment.child_count = nil
        expect(comment.get_cached_child_count).to eq(1)
      end

      it 'updates cached child count' do
        comment = make_comment(author, course_thread, "comment")
        expect(comment.get_cached_child_count).to eq(0)
        comment.child_count = 2
        expect(comment.get_cached_child_count).to eq(2)
        comment.update_cached_child_count
        expect(comment.get_cached_child_count).to eq(0)
      end
    end
  end
end

describe 'comment_with_es' do
  include_context 'search_enabled'

  let(:author) do
    create_test_user(42)
  end

  let(:standalone_thread) do
    make_thread(author, "Test standalone thread", "test_course", "test_commentable", :discussion, :standalone)
  end

  context 'with search_enabled, updating a comment' do
    it 'results in ES proxy called' do
      comment = make_comment(author, standalone_thread, "comment")
      expect(comment.__elasticsearch__).to receive(:update_document).once.and_call_original
      comment.update!({body: "changed"})
    end

    it 'results in ES proxy not called when explicitly disabled' do
      comment = make_comment(author, standalone_thread, "comment")
      expect(comment.__elasticsearch__).to_not receive(:update_document).and_call_original
      comment.without_es do
        comment.update!({body: "changed"})
      end
    end

    it 'leaves the enable_es variable intact despite any errors during update' do
      comment = make_comment(author, standalone_thread, "comment")
      expect(comment.__elasticsearch__).to_not receive(:update_document).and_call_original
      begin
        comment.without_es do
          raise  # this line simulates what would happen if the update command threw an exception
        end
      rescue
        expect(comment.es_enabled?).to be(true)
      end
    end
  end
end
