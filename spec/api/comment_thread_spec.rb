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
        thread.commentable_id.should == response_thread["commentable_id"]
        response_thread["children"].should be_nil
      end

      # This is a test to ensure that the username is included even if the
      # thread's author is the one looking at the comment. This is because of a
      # regression in which we used User.only(:id, :read_states). This worked
      # before we included the identity map, but afterwards, the user was
      # missing the username and was not refetched.
      it "includes the username even if the thread is being marked as read for the thread author" do
        thread = CommentThread.first
        expected_username = thread.author.username

        # We need to clear the IdentityMap after getting the expected data to
        # ensure that this spec fails when it should. If we don't do this, then
        # in the cases where the User is fetched without its username, the spec
        # won't fail because the User will already be in the identity map. 
        Mongoid::IdentityMap.clear

        get "/api/v1/threads/#{thread.id}", {:user_id => thread.author_id, :mark_as_read => true}
        last_response.should be_ok
        response_thread = parse last_response.body
        response_thread["username"].should == expected_username
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
        get "/api/v1/threads/5016a3caec5eb9a12300000b1"
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
        put "/api/v1/threads/#{thread.id}", body: "new body", title: "new title", commentable_id: "new_commentable_id"
        last_response.should be_ok
        changed_thread = CommentThread.find(thread.id)
        changed_thread.body.should == "new body"
        changed_thread.title.should == "new title"
        changed_thread.commentable_id.should == "new_commentable_id"
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
      let :default_params  do
        {body: "new comment", course_id: "1", user_id: User.first.id}
      end
      it "create a comment to the comment thread" do
        thread = CommentThread.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/threads/#{thread["id"]}/comments", default_params
        last_response.should be_ok
        changed_thread = CommentThread.find(thread["id"]).to_hash(recursive: true)
        changed_thread["children"].length.should == thread["children"].length + 1
        comment = changed_thread["children"].select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment["user_id"].should == user.id
      end
      it "allows anonymous comment" do
        thread = CommentThread.first.to_hash(recursive: true)
        post "/api/v1/threads/#{thread["id"]}/comments", default_params.merge(anonymous: true)
        last_response.should be_ok
        changed_thread = CommentThread.find(thread["id"]).to_hash(recursive: true)
        changed_thread["children"].length.should == thread["children"].length + 1
        comment = changed_thread["children"].select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment["anonymous"].should be_true
      end
      it "returns 400 when the thread does not exist" do
        post "/api/v1/threads/does_not_exist/comments", default_params
        last_response.status.should == 400
      end
      it "returns error when body or course_id does not exist, or when body is blank" do
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(body: nil)
        last_response.status.should == 400
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(course_id: nil)
        last_response.status.should == 400
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(body: "    \n      \n  ")
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
  describe "GET /api/v1/threads/tags" do
    it "get all tags used in threads" do
      CommentThread.recalculate_all_context_tag_weights!
      thread1 = CommentThread.all.to_a.first
      thread2 = CommentThread.all.to_a.last
      thread1.tags = "a, b, c"
      thread1.save
      thread2.tags = "d, e, f"
      thread2.save
      get "/api/v1/threads/tags"
      last_response.should be_ok
      tags = parse last_response.body
      tags.length.should == 6
    end
  end
  describe "GET /api/v1/threads/tags/autocomplete" do
    def create_comment_thread(tags)
      c = CommentThread.new(title: "Interesting question", body: "cool")
      c.course_id = "1"
      c.author = User.first
      c.tags = tags
      c.commentable_id = "1"
      c.save!
      c
    end
    it "returns autocomplete results" do
      CommentThread.delete_all
      CommentThread.recalculate_all_context_tag_weights!
      create_comment_thread "c++, clojure, common-lisp, c#, c, coffeescript"
      create_comment_thread "c++, clojure, common-lisp, c#, c"
      create_comment_thread "c++, clojure, common-lisp, c#"
      create_comment_thread "c++, clojure, common-lisp"
      create_comment_thread "c++, clojure"
      create_comment_thread "c++"
      get "/api/v1/threads/tags/autocomplete", value: "c"
      last_response.should be_ok
      results = parse last_response.body
      results.length.should == 5
      %w[c++ clojure common-lisp c# c].each_with_index do |tag, index|
        results[index].should == tag
      end
    end
  end
end
