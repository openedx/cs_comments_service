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

  context "#to_hash (recursive=true)" do
  
    before(:each) { @cid_seq = 10 }

    def stub_each_from_array(obj, ary)
      stub = obj.stub(:each)
      ary.each {|v| stub = stub.and_yield(v)}
      obj
    end

    def set_comment_results(thread, ary)
      # avoids an unrelated expecation error
      thread.stub(:endorsed?).and_return(true)
      rs = stub_each_from_array(double("rs"), ary)
      criteria = double("criteria")
      criteria.stub(:order_by).and_return(rs)
      Comment.stub(:where).with(comment_thread_id: thread.id).and_return(criteria)
    end

    def make_comment(parent=nil)
      c = Comment.new
      c.id = @cid_seq
      @cid_seq += 1
      c.parent_id = parent.nil? ? nil : parent.id
      c
    end

    it "nests comments in the correct order" do
      thread = CommentThread.new
      thread.id = 1
      thread.author = User.new

      c0 = make_comment()
      c00 = make_comment(c0)
      c01 = make_comment(c0)
      c010 = make_comment(c01)
      set_comment_results(thread, [c0, c00, c01, c010])

      h = thread.to_hash({:recursive => true})
      h["children"].size.should == 1 # c0
      h["children"][0]["id"].should == c0.id
      h["children"][0]["children"].size.should == 2 # c00, c01
      h["children"][0]["children"][0]["id"].should == c00.id
      h["children"][0]["children"][1]["id"].should == c01.id
      h["children"][0]["children"][1]["children"].size.should == 1 # c010
      h["children"][0]["children"][1]["children"][0]["id"].should == c010.id
      h["comments_count"].should == 4
    end

    it "handles orphaned child comments gracefully" do
      thread = CommentThread.new
      thread.id = 33
      thread.author = User.new

      c0 = make_comment()
      c00 = make_comment(c0)
      c000 = make_comment(c00)
      c1 = make_comment()
      c10 = make_comment(c1)
      c11 = make_comment(c1)
      c111 = make_comment(c11)
      # lose c0 and c11 from result set.  their descendants should
      # be silently skipped over.
      set_comment_results(thread, [c00, c000, c1, c10, c111])

      h = thread.to_hash({:recursive => true})
      h["children"].size.should == 1 # c1
      h["children"][0]["id"].should == c1.id
      h["children"][0]["children"].size.should == 1 # c10
      h["children"][0]["children"][0]["id"].should == c10.id
      h["comments_count"].should == 2
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

