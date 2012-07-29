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
end
