require 'spec_helper'

describe "app" do
  describe "comment threads" do
    before(:each) { init_without_subscriptions }
    describe "GET /api/v1/threads/:thread_id" do
      it "get information of a single comment thread" do
        thread = CommentThread.first
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        thread.title.should == response_thread["title"]
        thread.body.should == response_thread["body"]
        thread.course_id.should == response_thread["course_id"]
        thread.votes_point.should == response_thread["votes"]["point"]
        response_thread["children"].should be_nil
      end
      it "get information of a single comment thread with its comments" do
        thread = CommentThread.first
        get "/api/v1/threads/#{thread.id}", recursive: true
        last_response.should be_ok
        response_thread = parse last_response.body
        thread.title.should == response_thread["title"]
        thread.body.should == response_thread["body"]
        thread.course_id.should == response_thread["course_id"]
        thread.votes_point.should == response_thread["votes"]["point"]
        response_thread["children"].should_not be_nil
        response_thread["children"].length.should == thread.root_comments.length
        response_thread["children"].index{|c| c["body"] == thread.root_comments.first.body}.should_not be_nil
      end
      it "returns 400 when the thread does not exist" do
        get "/api/v1/threads/does_not_exist"
        last_response.status.should == 400
      end
      it "get information of a single comment thread with its tags" do
        thread = CommentThread.new
        thread.title = "new thread"
        thread.body = "hahaah"
        thread.course_id = "1"
        thread.commentable_id = "1"
        thread.author = User.first
        thread.tags = "taga, tagb, tagc"
        thread.save!
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        response_thread["tags"].length.should == 3
        response_thread["tags"].should include "taga"
        response_thread["tags"].should include "tagb"
        response_thread["tags"].should include "tagc"
      end
    end
    describe "PUT /api/v1/threads/:thread_id" do
      it "update information of comment thread" do
        thread = CommentThread.first
        put "/api/v1/threads/#{thread.id}", body: "new body", title: "new title"
        last_response.should be_ok
        changed_thread = CommentThread.find(thread.id)
        changed_thread.body.should == "new body"
        changed_thread.title.should == "new title"
      end
      it "returns 400 when the thread does not exist" do
        put "/api/v1/threads/does_not_exist", body: "new body", title: "new title"
        last_response.status.should == 400
      end
      it "updates tag of comment thread" do
        thread = CommentThread.first
        put "/api/v1/threads/#{thread.id}", tags: "haha, hoho, huhu"
        last_response.should be_ok
        thread.reload
        thread.tags_array.length.should == 3
        thread.tags_array.should include "haha"
        thread.tags_array.should include "hoho"
        thread.tags_array.should include "huhu"
        put "/api/v1/threads/#{thread.id}", tags: "aha, oho"
        last_response.should be_ok
        thread.reload
        thread.tags_array.length.should == 2
        thread.tags_array.should include "aha"
        thread.tags_array.should include "oho"
      end
    end
    describe "POST /api/v1/threads/:thread_id/comments" do
      it "create a comment to the comment thread" do
        thread = CommentThread.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/threads/#{thread["id"]}/comments", body: "new comment", course_id: "1", user_id: User.first.id
        last_response.should be_ok
        changed_thread = CommentThread.find(thread["id"]).to_hash(recursive: true)
        changed_thread["children"].length.should == thread["children"].length + 1
        comment = changed_thread["children"].select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment["user_id"].should == user.id
      end
      it "allows anonymous comment" do
        thread = CommentThread.first.to_hash(recursive: true)
        post "/api/v1/threads/#{thread["id"]}/comments", body: "new comment", course_id: "1", user_id: nil
        last_response.should be_ok
        changed_thread = CommentThread.find(thread["id"]).to_hash(recursive: true)
        changed_thread["children"].length.should == thread["children"].length + 1
        comment = changed_thread["children"].select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
      end
      it "returns 400 when the thread does not exist" do
        post "/api/v1/threads/does_not_exist/comments", body: "new comment", course_id: "1", user_id: User.first.id
        last_response.status.should == 400
      end
    end
    describe "DELETE /api/v1/threads/:thread_id" do
      it "delete the comment thread and its comments" do
        thread = CommentThread.first.to_hash
        delete "/api/v1/threads/#{thread['id']}"
        last_response.should be_ok
        CommentThread.where(title: thread["title"]).first.should be_nil
      end
      it "returns 400 when the thread does not exist" do
        delete "/api/v1/threads/does_not_exist"
        last_response.status.should == 400
      end
    end
  end
end
