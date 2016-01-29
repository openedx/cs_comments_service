require 'spec_helper'
require 'unicode_shared_examples'

describe CommentThread do
  let(:author) do
    create_test_user(42)
  end

  before (:each) do
    [Comment, CommentThread, User].each(&:delete_all).each(&:remove_indexes).each(&:create_indexes)
  end

  context "sorting" do
    it "indexes comments in hierarchical order" do

      author = create_test_user('billy')

      thread = CommentThread.new(title: "test case", body: "testing 123", course_id: "foo", commentable_id: "bar")
      thread.thread_type = :discussion
      thread.author = author
      thread.save!

      a = thread.comments.new(body: "a", course_id: "foo")
      a.author = author
      a.save!
      
      b = a.children.new(body: "b", course_id: "foo")
      b.author = author
      b.comment_thread = thread
      b.save!
      
      c = b.children.new(body: "c", course_id: "foo")
      c.author = author
      c.comment_thread = thread
      c.save!
      
      d = b.children.new(body: "d", course_id: "foo")
      d.author = author
      d.comment_thread = thread
      d.save!
      
      e = a.children.new(body: "e", course_id: "foo")
      e.author = author
      e.comment_thread = thread
      e.save!
      
      f = thread.comments.new(body: "f", course_id: "foo")
      f.author = author
      f.save!
      
      seq = []
      rs = Comment.where(comment_thread_id: thread.id).order_by({"sk"=>1})
      rs.each.map {|c| seq << c.body}
      seq.should == ["a", "b", "c", "d", "e", "f"]

    end
  end

  context "scoping" do
    before(:each) do
      author = create_test_user('billy')

      # create a course thread
      course_thread = CommentThread.new(title: "course thread", body: "testing 123", course_id: "foo", commentable_id: "bar")
      course_thread.thread_type = :discussion
      course_thread.author = author
      course_thread.context = :course
      course_thread.save!

      # create a course thread (using the default context rather than setting it explicitly)
      course_thread = CommentThread.new(title: "course thread", body: "testing 123", course_id: "foo", commentable_id: "bar")
      course_thread.thread_type = :discussion
      course_thread.author = author
      course_thread.save!

      # create a standalone thread
      standalone_thread = CommentThread.new(title: "standalone_thread thread", body: "testing 123", course_id: "foo", commentable_id: "bear")
      standalone_thread.thread_type = :discussion
      standalone_thread.author = author
      standalone_thread.context = :standalone
      standalone_thread.save!
    end
    
    context '#unscoped' do
      it 'returns all' do
        expect(CommentThread.count).to eq(3)
      end
    end

    context "#course_context" do
      it 'returns all' do
        threads = CommentThread.course_context
        expect(threads.count).to eq(2)
        expect(threads.first.title).to eq("course thread")
      end
    end

    context "#standalone_context" do
      it 'returns all' do
        threads = CommentThread.standalone_context
        expect(threads.count).to eq(1)
        expect(threads.first.title).to eq("standalone_thread thread")
      end
    end
  end

  def test_unicode_data(text)
    thread = make_thread(author, text, "unicode_course", commentable_id: "unicode_commentable")
    retrieved = CommentThread.find(thread._id)
    retrieved.title.should == text
    retrieved.body.should == text
  end

  include_examples "unicode data"
end

