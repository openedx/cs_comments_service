require 'spec_helper'

describe "app" do
  describe "comments" do
    before(:each) { init_without_subscriptions }
    describe "GET /api/v1/comments/:comment_id" do
      it "returns JSON" do
        comment = Comment.first
        get "/api/v1/comments/#{comment.id}"
        last_response.should be_ok
        last_response.content_type.should == "application/json;charset=utf-8"
      end
      it "retrieve information of a single comment" do
        comment = Comment.first
        get "/api/v1/comments/#{comment.id}"
        last_response.should be_ok
        retrieved = parse last_response.body
        retrieved["body"].should == comment.body
        retrieved["endorsed"].should == comment.endorsed
        retrieved["id"].should == comment.id.to_s
        retrieved["children"].should be_nil
        retrieved["votes"]["point"].should == comment.votes_point
        retrieved["depth"].should == comment.depth
      end
      it "retrieve information of a single comment with its sub comments" do
        comment = Comment.first
        get "/api/v1/comments/#{comment.id}", recursive: true
        last_response.should be_ok
        retrieved = parse last_response.body
        retrieved["body"].should == comment.body
        retrieved["endorsed"].should == comment.endorsed
        retrieved["id"].should == comment.id.to_s
        retrieved["votes"]["point"].should == comment.votes_point
        retrieved["children"].length.should == comment.children.length
        retrieved["children"].select{|c| c["body"] == comment.children.first.body}.first.should_not be_nil
      end
      it "returns 400 when the comment does not exist" do
        get "/api/v1/comments/does_not_exist"
        last_response.status.should == 400
      end
    end
    describe "PUT /api/v1/comments/:comment_id" do
      it "update information of the comment" do
        comment = Comment.first
        put "/api/v1/comments/#{comment.id}", body: "new body", endorsed: true
        last_response.should be_ok
        new_comment = Comment.find(comment.id)
        new_comment.body.should == "new body"
        new_comment.endorsed.should == true
      end
      it "returns 400 when the comment does not exist" do
        put "/api/v1/comments/does_not_exist", body: "new body", endorsed: true
        last_response.status.should == 400
      end
      it "returns 503 when the post hash is blocked" do
        comment = Comment.first
        put "/api/v1/comments/#{comment.id}", body: "BLOCKED POST", endorsed: true
        last_response.status.should == 503
      end
    end
    describe "POST /api/v1/comments/:comment_id" do
      it "create a sub comment to the comment" do
        comment = Comment.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/comments/#{comment["id"]}", body: "new comment", course_id: "1", user_id: User.first.id
        last_response.should be_ok
        changed_comment = Comment.find(comment["id"]).to_hash(recursive: true)
        changed_comment["children"].length.should == comment["children"].length + 1
        subcomment = changed_comment["children"].select{|c| c["body"] == "new comment"}.first
        subcomment.should_not be_nil
        subcomment["user_id"].should == user.id
      end
      it "returns 400 when the comment does not exist" do
        post "/api/v1/comments/does_not_exist", body: "new comment", course_id: "1", user_id: User.first.id
        last_response.status.should == 400
      end
      it "returns 503 when the post hash is blocked" do
        comment = Comment.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/comments/#{comment["id"]}", body: "BLOCKED POST", course_id: "1", user_id: User.first.id
        last_response.status.should == 503
      end
    end
    describe "DELETE /api/v1/comments/:comment_id" do
      it "delete the comment and its sub comments" do
        comment = Comment.first
        cnt_comments = comment.descendants_and_self.length
        prev_count = Comment.count
        delete "/api/v1/comments/#{comment.id}"
        Comment.count.should == prev_count - cnt_comments
        Comment.all.select{|c| c.id == comment.id}.first.should be_nil
      end
      it "returns 400 when the comment does not exist" do
        delete "/api/v1/comments/does_not_exist"
        last_response.status.should == 400
      end
    end
  end
end
