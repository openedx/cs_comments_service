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
    expect(reader.upvoted_ids).to eq([])
  end

  it "should have one vote if it voted once" do
    expect(reader.upvoted_ids).to eq([])
    reader.vote(thread, :up)
    expect(reader.upvoted_ids).to eq([thread._id])
  end
end
