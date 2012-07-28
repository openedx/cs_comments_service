require 'spec_helper'

describe "app" do
  describe "commentables" do
    before(:each) { init_without_subscriptions }
    describe "DELETE /api/v1/:commentable_id/threads" do
      it "delete all associated threads and comments of a commentable" do
        delete '/api/v1/question_1/threads'
        last_response.should be_ok
        Commentable.find("question_1").comment_threads.count.should == 0
      end
      it "handle normally when commentable does not exist" do
        delete '/api/v1/does_not_exist/threads'
        last_response.should be_ok
      end
    end
    describe "GET /api/v1/:commentable_id/threads" do
      it "get all comment threads associated with a commentable object" do
        get "/api/v1/question_1/threads"
        last_response.should be_ok
        threads = parse last_response.body
        threads.length.should == 2
        threads.index{|c| c["body"] == "can anyone help me?"}.should_not be_nil
        threads.index{|c| c["body"] == "it is unsolvable"}.should_not be_nil
      end
      it "get all comment threads and comments associated with a commentable object" do
        get "/api/v1/question_1/threads", recursive: true
        last_response.should be_ok
        threads = parse last_response.body
        threads.length.should == 2
        threads.index{|c| c["body"] == "can anyone help me?"}.should_not be_nil
        threads.index{|c| c["body"] == "it is unsolvable"}.should_not be_nil
        thread = threads.select{|c| c["body"] == "can anyone help me?"}.first
        children = thread["children"]
        children.length.should == 2
        children.index{|c| c["body"] == "this problem is so easy"}.should_not be_nil
        children.index{|c| c["body"] =~ /^see the textbook/}.should_not be_nil
        so_easy = children.select{|c| c["body"] == "this problem is so easy"}.first
        so_easy["children"].length.should == 1
        not_for_me = so_easy["children"].first
        not_for_me["body"].should == "not for me!"
        not_for_me["children"].length.should == 1
        not_for_me["children"].first["body"].should == "not for me neither!"
      end
      it "returns an empty array when the commentable object does not exist (no threads)" do
        get "/api/v1/does_not_exist/threads"
        last_response.should be_ok
        threads = parse last_response.body
        threads.length.should == 0
      end
    end
    describe "POST /api/v1/:commentable_id/threads" do
      it "create a new comment thread for the commentable object" do
        post '/api/v1/question_1/threads', title: "Interesting question", body: "cool", course_id: "1", user_id: "1"
        last_response.should be_ok
        CommentThread.count.should == 3
        CommentThread.where(title: "Interesting question").first.should_not be_nil
      end
      it "allows anonymous thread" do
        post '/api/v1/question_1/threads', title: "Interesting question", body: "cool", course_id: "1"
        last_response.should be_ok
        CommentThread.count.should == 3
        CommentThread.where(title: "Interesting question").first.should_not be_nil
      end
      it "create a new comment thread for a new commentable object" do
        post '/api/v1/does_not_exist/threads', title: "Interesting question", body: "cool", course_id: "1", user_id: "1"
        last_response.should be_ok
        Commentable.find("does_not_exist").comment_threads.length.should == 1
        Commentable.find("does_not_exist").comment_threads.first.body.should == "cool"
      end
      it "create a new comment thread with tag" do
        post '/api/v1/question_1/threads', title: "Interesting question", body: "cool", course_id: "1", user_id: "1", tags: "a, b, c"
        last_response.should be_ok
        CommentThread.count.should == 3
        thread = CommentThread.where(title: "Interesting question").first
        thread.tags_array.length.should == 3
        thread.tags_array.should include "a"
        thread.tags_array.should include "b"
        thread.tags_array.should include "c"
      end
    end
  end
end
