require 'spec_helper'

describe "app" do
  describe "votes" do

    before(:each) do
      init_without_subscriptions
      set_api_key_header
    end

    describe "PUT /api/v1/comments/:comment_id/votes" do
      it "create or update the vote on the comment" do
        user = User.first
        comment = Comment.first
        prev_up_votes = comment.up_votes_count
        prev_down_votes = comment.down_votes_count
        put "/api/v1/comments/#{comment.id}/votes", user_id: user.id, value: "down"
        comment = Comment.find(comment.id)
        comment.up_votes_count.should == prev_up_votes - 1
        comment.down_votes_count.should == prev_down_votes + 1
      end
      it "returns 400 when the comment does not exist" do
        put "/api/v1/comments/does_not_exist/votes", user_id: User.first.id, value: "down"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
      it "returns 400 when user_id is not provided" do
        put "/api/v1/comments/#{Comment.first.id}/votes", value: "down"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:user_id_is_required)
      end
      it "returns 400 when value is not provided or invalid" do
        put "/api/v1/comments/#{Comment.first.id}/votes", user_id: User.first.id
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:value_is_required)
        put "/api/v1/comments/#{Comment.first.id}/votes", user_id: User.first.id, value: "superdown"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:value_is_invalid)
      end
    end
    describe "DELETE /api/v1/comments/:comment_id/votes" do
      it "unvote on the comment" do
        user = User.first
        comment = Comment.first
        prev_up_votes = comment.up_votes_count
        prev_down_votes = comment.down_votes_count
        delete "/api/v1/comments/#{comment.id}/votes", user_id: user.id
        comment = Comment.find(comment.id)
        comment.up_votes_count.should == prev_up_votes - 1
        comment.down_votes_count.should == prev_down_votes
      end
      it "unvote on the comment is idempotent" do
        user = User.first
        comment = Comment.first
        prev_up_votes = comment.up_votes_count
        prev_down_votes = comment.down_votes_count
        delete "/api/v1/comments/#{comment.id}/votes", user_id: user.id
        # multiple calls to unvote endpoint should not change the data
        delete "/api/v1/comments/#{comment.id}/votes", user_id: user.id
        comment = Comment.find(comment.id)
        comment.up_votes_count.should == prev_up_votes - 1
        comment.down_votes_count.should == prev_down_votes
      end
      it "returns 400 when the comment does not exist" do
        delete "/api/v1/comments/does_not_exist/votes", user_id: User.first.id
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
      it "returns 400 when user_id is not provided" do
        delete "/api/v1/comments/#{Comment.first.id}/votes"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:user_id_is_required)
      end
    end
    describe "PUT /api/v1/threads/:thread_id/votes" do
      it "create or update the vote on the thread" do
        user = User.first
        thread = CommentThread.first
        prev_up_votes = thread.up_votes_count
        prev_down_votes = thread.down_votes_count
        put "/api/v1/threads/#{thread.id}/votes", user_id: user.id, value: "down"
        thread = CommentThread.find(thread.id)
        thread.up_votes_count.should == prev_up_votes - 1
        thread.down_votes_count.should == prev_down_votes + 1
      end
      it "vote on the thread is idempotent" do
        user = User.first
        thread = CommentThread.first
        prev_up_votes = thread.up_votes_count
        prev_down_votes = thread.down_votes_count
        put "/api/v1/threads/#{thread.id}/votes", user_id: user.id, value: "down"
        put "/api/v1/threads/#{thread.id}/votes", user_id: user.id, value: "down"
        thread = CommentThread.find(thread.id)
        thread.up_votes_count.should == prev_up_votes - 1
        thread.down_votes_count.should == prev_down_votes + 1
      end
      it "returns 400 when the thread does not exist" do
        put "/api/v1/threads/does_not_exist/votes", user_id: User.first.id, value: "down"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
      it "returns 400 when user_id is not provided" do
        put "/api/v1/threads/#{CommentThread.first.id}/votes", value: "down"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:user_id_is_required)
      end
      it "returns 400 when value is not provided or invalid" do
        put "/api/v1/threads/#{CommentThread.first.id}/votes", user_id: User.first.id
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:value_is_required)
        put "/api/v1/threads/#{CommentThread.first.id}/votes", user_id: User.first.id, value: "superdown"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:value_is_invalid)
      end
    end
    describe "DELETE /api/v1/threads/:thread_id/votes" do
      it "unvote on the thread" do
        user = User.first
        thread = CommentThread.first
        prev_up_votes = thread.up_votes_count
        prev_down_votes = thread.down_votes_count
        delete "/api/v1/threads/#{thread.id}/votes", user_id: user.id
        thread = CommentThread.find(thread.id)
        thread.up_votes_count.should == prev_up_votes - 1
        thread.down_votes_count.should == prev_down_votes
      end
      it "returns 400 when the comment does not exist" do
        delete "/api/v1/threads/does_not_exist/votes", user_id: User.first.id
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
      it "returns 400 when user_id is not provided" do
        delete "/api/v1/threads/#{CommentThread.first.id}/votes"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:user_id_is_required)
      end
    end
  end
end
