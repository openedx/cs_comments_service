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
end
