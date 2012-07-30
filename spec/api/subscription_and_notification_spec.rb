require 'spec_helper'

describe "app" do
  describe "subscriptions and notifications" do
    before(:each) { init_with_subscriptions }
    describe "GET /api/v1/users/:user_id/notifications" do
      it "get all notifications on the subscribed comment threads for the user" do
        user = User.find("1")
        get "/api/v1/users/#{user.external_id}/notifications"
        last_response.should be_ok
        notifications = parse last_response.body
        so_easy = Comment.all.select{|c| c.body == "this problem is so easy"}.first
        not_for_me_neither = Comment.all.select{|c| c.body == "not for me neither!"}.first
        notification_so_easy = notifications.select{|f| f["notification_type"] == "post_reply" and f["info"]["comment_id"] == so_easy.id.to_s}.first
        notification_so_easy.should_not be_nil
        notification_not_for_me_neither = notifications.select{|f| f["notification_type"] == "post_reply" and f["info"]["comment_id"] == not_for_me_neither.id.to_s}.first
        notification_not_for_me_neither.should_not be_nil
      end
      it "returns empty array if user does not exist" do #TODO may change later if have user service
        get "/api/v1/users/does_not_exist/notifications"
        parse(last_response.body).length.should == 0
      end
      it "get all notifications on the subscribed commentable for the user" do
        user = User.find("1")
        get "/api/v1/users/#{user.external_id}/notifications"
        last_response.should be_ok
        notifications = parse last_response.body
        notifications.select{|f| f["notification_type"] == "post_topic"}.length.should == 1
        problem_wrong = notifications.select{|f| f["notification_type"] == "post_topic"}.first
        problem_wrong["info"]["thread_title"].should == "This problem is wrong"
      end
      it "get all notifications on the followed user for the user" do
        user = User.find("2")
        get "/api/v1/users/#{user.external_id}/notifications"
        last_response.should be_ok
        notifications = parse last_response.body
        notifications.select{|f| f["info"]["thread_title"] =~ /what to say/}.first.should_not be_nil
      end
    end
    describe "POST /api/v1/users/:user_id/subscriptions" do
      it "follow user" do
        user1 = User.find("1")
        user2 = User.find("2")
        post "/api/v1/users/#{user1.external_id}/subscriptions", source_type: "user", source_id: user2.external_id
        last_response.should be_ok
        User.find("2").followers.length.should == 1
        User.find("2").followers.should include user1
      end
      it "does not follow the same user twice" do
        user1 = User.find("1")
        user2 = User.find("2")
        post "/api/v1/users/#{user1.external_id}/subscriptions", source_type: "user", source_id: user2.external_id
        post "/api/v1/users/#{user1.external_id}/subscriptions", source_type: "user", source_id: user2.external_id
        last_response.should be_ok
        User.find("2").followers.length.should == 1
      end
      it "does not follow oneself" do
        user = User.find_or_create_by(external_id: "3")
        post "/api/v1/users/#{user.external_id}/subscriptions", source_type: "user", source_id: user.external_id
        last_response.status.should == 400
        user.reload.followers.length.should == 0
      end
      it "unfollow user" do
        user1 = User.find("1")
        user2 = User.find("2")
        delete "/api/v1/users/#{user2.external_id}/subscriptions", source_type: "user", source_id: user1.external_id
        last_response.should be_ok
        User.find("1").followers.length.should == 0
      end
      it "respond ok when unfollowing user twice" do
        user1 = User.find("1")
        user2 = User.find("2")
        delete "/api/v1/users/#{user2.external_id}/subscriptions", source_type: "user", source_id: user1.external_id
        delete "/api/v1/users/#{user2.external_id}/subscriptions", source_type: "user", source_id: user1.external_id
        last_response.should be_ok
        User.find("1").followers.length.should == 0
      end
      it "subscribe a commentable" do
        user3 = User.find_or_create_by(external_id: "3")
        post "/api/v1/users/#{user3.external_id}/subscriptions", source_type: "other", source_id: "question_1"
        last_response.should be_ok
        Commentable.find("question_1").subscribers.length.should == 3
        Commentable.find("question_1").subscribers.should include user3
      end
      it "unsubscribe a commentable" do
        user2 = User.find_or_create_by(external_id: "2")
        delete "/api/v1/users/#{user2.external_id}/subscriptions", source_type: "other", source_id: "question_1"
        last_response.should be_ok
        Commentable.find("question_1").subscribers.length.should == 1
        Commentable.find("question_1").subscribers.should_not include user2
      end
      it "subscribe a comment thread" do
        user1 = User.find_or_create_by(external_id: "1")
        thread = CommentThread.where(body: "it is unsolvable").first
        post "/api/v1/users/#{user1.external_id}/subscriptions", source_type: "thread", source_id: thread.id
        last_response.should be_ok
        thread = CommentThread.where(body: "it is unsolvable").first
        thread.subscribers.length.should == 2
        thread.subscribers.should include user1
      end
      it "unsubscribe a comment thread" do
        user2 = User.find_or_create_by(external_id: "2")
        thread = CommentThread.where(body: "it is unsolvable").first
        delete "/api/v1/users/#{user2.external_id}/subscriptions", source_type: "thread", source_id: thread.id
        last_response.should be_ok
        thread = CommentThread.where(body: "it is unsolvable").first
        thread.subscribers.length.should == 0
      end
    end
  end
end
