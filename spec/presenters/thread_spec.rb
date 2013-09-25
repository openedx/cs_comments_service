require 'spec_helper'

describe ThreadPresenter do
 context "#to_hash_array" do
  
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
      # stub Content, not Comment, because that's the model we will be querying against
      Content.stub(:where).with(comment_thread_id: thread.id).and_return(criteria)
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

      h = ThreadPresenter.new([thread], nil, thread.course_id).to_hash_array(true).first
      h["children"].size.should == 1 # c0
      h["children"][0]["id"].should == c0.id
      h["children"][0]["children"].size.should == 2 # c00, c01
      h["children"][0]["children"][0]["id"].should == c00.id
      h["children"][0]["children"][1]["id"].should == c01.id
      h["children"][0]["children"][1]["children"].size.should == 1 # c010
      h["children"][0]["children"][1]["children"][0]["id"].should == c010.id
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

      h = ThreadPresenter.new([thread], nil, thread.course_id).to_hash_array(true).first
      h["children"].size.should == 1 # c1
      h["children"][0]["id"].should == c1.id
      h["children"][0]["children"].size.should == 1 # c10
      h["children"][0]["children"][0]["id"].should == c10.id
    end
  end
end

