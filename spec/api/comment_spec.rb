require 'spec_helper'
require 'unicode_shared_examples'

describe "app" do

  before(:each) { set_api_key_header }

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
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end

      def test_unicode_data(text)
        comment = make_comment(User.first, CommentThread.first, text)
        get "/api/v1/comments/#{comment.id}"
        last_response.should be_ok
        retrieved = parse last_response.body
        retrieved["body"].should == text
      end

      include_examples "unicode data"
    end
    describe "PUT /api/v1/comments/:comment_id" do
      def test_update_endorsed(true_val, false_val)
        comment = Comment.first
        before = DateTime.now
        put "/api/v1/comments/#{comment.id}", endorsed: true_val, endorsement_user_id: "#{User.first.id}"
        after = DateTime.now
        last_response.should be_ok
        comment.reload
        comment.endorsed.should == true
        comment.endorsement.should_not be_nil
        comment.endorsement["user_id"].should == "#{User.first.id}"
        comment.endorsement["time"].should be_between(before, after)
        put "/api/v1/comments/#{comment.id}", endorsed: false_val
        last_response.should be_ok
        comment.reload
        comment.endorsed.should == false
        comment.endorsement.should be_nil
      end
      it "updates endorsed correctly" do
        test_update_endorsed(true, false)
      end
      it "updates endorsed correctly with Pythonic values" do
        test_update_endorsed("True", "False")
      end
      it "updates body correctly" do
        comment = Comment.first
        put "/api/v1/comments/#{comment.id}", body: "new body"
        last_response.should be_ok
        comment.reload
        comment.body.should == "new body"
      end
      it "can update endorsed and body simultaneously" do
        comment = Comment.first
        put "/api/v1/comments/#{comment.id}", body: "new body", endorsed: true
        last_response.should be_ok
        comment.reload
        comment.body.should == "new body"
        comment.endorsed.should == true
      end
      it "returns 400 when the comment does not exist" do
        put "/api/v1/comments/does_not_exist", body: "new body", endorsed: true
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
      it "returns 503 and does not update when the post hash is blocked" do
        comment = Comment.first
        original_body = comment.body
        put "/api/v1/comments/#{comment.id}", body: "BLOCKED POST", endorsed: true
        last_response.status.should == 503
        parse(last_response.body).first.should == I18n.t(:blocked_content_with_body_hash, :hash => Digest::MD5.hexdigest("blocked post"))
        comment.reload
        comment.body.should == original_body
      end

      def test_unicode_data(text)
        comment = Comment.first
        put "/api/v1/comments/#{comment.id}", body: text
        last_response.should be_ok
        comment.body.should == text
      end

      include_examples "unicode data"
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
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
      it "returns 503 and does not create when the post hash is blocked" do
        comment = Comment.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/comments/#{comment["id"]}", body: "BLOCKED POST", course_id: "1", user_id: User.first.id
        last_response.status.should == 503
        parse(last_response.body).first.should == I18n.t(:blocked_content_with_body_hash, :hash => Digest::MD5.hexdigest("blocked post"))
        Comment.where(body: "BLOCKED POST").to_a.should be_empty
      end

      def test_unicode_data(text)
        parent = Comment.first
        post "/api/v1/comments/#{parent.id}", body: text, course_id: parent.course_id, user_id: User.first.id
        last_response.should be_ok
        parent.children.where(body: text).should_not be_empty
      end

      include_examples "unicode data"
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
      it "can delete a sub comment" do
        parent = CommentThread.first.comments.first
        sub_comment = parent.children.first
        id = sub_comment.id
        delete "/api/v1/comments/#{id}"
        Comment.where(:id => id).should be_empty
        parent.children.where(:id => id).should be_empty
      end
      it "returns 400 when the comment does not exist" do
        delete "/api/v1/comments/does_not_exist"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
    end
  end
end
