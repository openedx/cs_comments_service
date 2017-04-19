require 'spec_helper'
require 'unicode_shared_examples'

describe User do
  let(:author) { create_test_user(666) }
  let(:reader) { create_test_user(667) }
  let(:thread) { make_standalone_thread(author) }

  before(:each) do
    [Comment, CommentThread, User].each(&:delete_all).each(&:remove_indexes).each(&:create_indexes)
  end

  it "should have no votes if it never voted" do
    reader.upvoted_ids.should == []
  end

  it "should have one vote if it voted once" do
    reader.upvoted_ids.should == []
    reader.vote(thread, :up)
    reader.upvoted_ids.should == [thread._id]
  end
end
