require 'spec_helper'

describe CommentThread do
  it "validates tag name" do
    CommentThread.tag_name_valid?("a++").should be_true
    CommentThread.tag_name_valid?("a++ b++ c++").should be_true
    CommentThread.tag_name_valid?("a#b+").should be_true
    CommentThread.tag_name_valid?("a##").should be_true
    CommentThread.tag_name_valid?("a#-b#").should be_true
    CommentThread.tag_name_valid?("000a123").should be_true
    CommentThread.tag_name_valid?("artificial-intelligence").should be_true
    CommentThread.tag_name_valid?("artificial intelligence").should be_true
    CommentThread.tag_name_valid?("well-known formulas").should be_true

    CommentThread.tag_name_valid?("a#+b#").should be_false
    CommentThread.tag_name_valid?("a# +b#").should be_false
    CommentThread.tag_name_valid?("--a").should be_false
    CommentThread.tag_name_valid?("artificial_intelligence").should be_false
    CommentThread.tag_name_valid?("#this-is-a-tag").should be_false
    CommentThread.tag_name_valid?("_this-is-a-tag").should be_false
    CommentThread.tag_name_valid?("this-is+a-tag").should be_false
  end

  context "endorsed?" do

    it "knows if it is #endorsed?" do
      thread = CommentThread.new
      criteria = build_criteria(thread, :exists? => true)
      thread.endorsed?.should be_true
    end

    it "knows when it is not #endorsed?" do
      thread = CommentThread.new
      criteria = build_criteria(thread, :exists? => false)
      thread.endorsed?.should be_false
    end

    def build_criteria(thread, options)
      double("criteria").tap do |criteria|
        comments = double("relation")
        comments.stub(:where).with(endorsed: true).and_return(criteria)
        thread.stub(:comments).and_return(comments)
        criteria.stub(options)
      end
    end
  end


  context "sorting" do

    before (:each) do
      [Comment, CommentThread, User].each(&:delete_all).each(&:remove_indexes).each(&:create_indexes)
    end

    it "indexes comments in hierarchical order" do

      author = create_test_user('billy')

      thread = CommentThread.new(title: "test case", body: "testing 123", course_id: "foo", commentable_id: "bar")
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

end

