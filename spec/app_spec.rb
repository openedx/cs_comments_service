require 'spec_helper'
require 'yajl'

describe "app" do
  describe "comments" do
    before :each do
      Comment.delete_all
      CommentThread.delete_all
    end
    describe "POST on /api/v1/commentables/:commentable_type/:commentable_id/comments" do
      it "should create a top-level comment with correct body, title, user_id, and course_id" do
        post "/api/v1/commentables/questions/1/comments", :body => "comment body", :title => "comment title", :user_id => 1, :course_id => 1
        last_response.should be_ok
        comment = CommentThread.first.root_comments.first
        comment.should_not be_nil
        comment.body.should == "comment body"
        comment.title.should == "comment title"
        comment.user_id.should == 1
        comment.user_id.should == 1
      end
    end
    describe "POST on /api/v1/comments/:comment_id" do
      before :each do
        CommentThread.create! :commentable_type => "questions", :commentable_id => 1
        CommentThread.first.root_comments.create :body => "top comment", :title => "top", :user_id => 1, :course_id => 1, :comment_thread_id => CommentThread.first.id
      end
      it "should create a sub comment with correct body, title, user_id, and course_id" do
        post "/api/v1/comments/#{CommentThread.first.root_comments.first.id}", 
             :body => "comment body", :title => "comment title", :user_id => 1, :course_id => 1
        last_response.should be_ok
        comment = CommentThread.first.root_comments.first.children.first
        comment.should_not be_nil
        comment.body.should == "comment body"
        comment.title.should == "comment title"
        comment.user_id.should == 1
        comment.user_id.should == 1
      end
      it "should not create a sub comment for the super comment" do
        post "/api/v1/comments/#{CommentThread.first.super_comment.id}", 
             :body => "comment body", :title => "comment title", :user_id => 1, :course_id => 1
        last_response.status.should == 400
      end
    end
    describe "GET on /api/v1/commentables/:commentable_type/:commentable_id/comments" do
      it "should create a corresponding comment thread with a super comment" do
        get "/api/v1/commentables/questions/1/comments"
        last_response.should be_ok
        comment_thread = CommentThread.first
        comment_thread.should_not be_nil
        comment_thread.super_comment.should_not be_nil
      end
      it "should create a corresponding comment thread with correct type and id" do
        get "/api/v1/commentables/questions/1/comments"
        last_response.should be_ok
        comment_thread = CommentThread.first
        comment_thread.commentable_type.should == 'questions'
        comment_thread.commentable_id.should == '1'
      end
      it "returns an empty array when there are no comments" do
        get "/api/v1/commentables/questions/1/comments"
        last_response.should be_ok
        comments = Yajl::Parser.parse last_response.body
        comments.length.should == 0
      end
      it "retrieves all comments with their votes in a nested structure in json format" do
        comment_thread = CommentThread.create! :commentable_type => "questions", :commentable_id => 1
        comment = []
        sub_comment = []
        comment << (comment_thread.root_comments.create :body => "top comment", :title => "top 0", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id)
        sub_comment << (comment[0].children.create :body => "comment body", :title => "comment title 0", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id)
        sub_comment << (comment[0].children.create :body => "comment body", :title => "comment title 1", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id)
        Vote.create! :value => "up", :comment_id => comment[0].id, :user_id => 1
        Vote.create! :value => "up", :comment_id => comment[0].id, :user_id => 2
        Vote.create! :value => "up", :comment_id => comment[0].id, :user_id => 3
        Vote.create! :value => "up", :comment_id => comment[0].id, :user_id => 4
        Vote.create! :value => "down", :comment_id => comment[0].id, :user_id => 5
        Vote.create! :value => "down", :comment_id => comment[0].id, :user_id => 6
        Vote.create! :value => "down", :comment_id => comment[0].id, :user_id => 7
        get "/api/v1/commentables/questions/1/comments"
        last_response.should be_ok
        comments = Yajl::Parser.parse last_response.body
        comments.length.should == 1
        c = comments[0]
        c["title"].should == "top 0"
        c["id"].should == comment[0].id
        c["votes"]["up"].should == 4
        c["votes"]["down"].should == 3
        c["comment_thread_id"].should == comment_thread.id
        c["created_at"].should_not be_nil
        c["updated_at"].should_not be_nil
        c["children"].length.should == 2
        c["children"][0]["title"].should == "comment title 0"
        c["children"][0]["id"].should == sub_comment[0].id
        c["children"][0]["created_at"].should_not be_nil
        c["children"][0]["updated_at"].should_not be_nil
      end
    end
    describe "DELETE on /api/v1/commentables/:commentable_type/:commentable_id" do
      before :each do
        comment_thread = CommentThread.create! :commentable_type => "questions", :commentable_id => 1
        comment = []
        sub_comment = []
        comment << (comment_thread.root_comments.create :body => "top comment", :title => "top 0", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id)
        sub_comment << (comment[0].children.create :body => "comment body", :title => "comment title 0", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id)
        comment << (comment_thread.root_comments.create :body => "top comment", :title => "top 1", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id)
        sub_comment << (comment[1].children.create :body => "comment body", :title => "comment title 1", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id)
      end
      it "should return error when called on a nonexisted thread" do
        delete "/api/v1/commentables/i_do_not_exist/1"
        last_response.status.should == 400
      end
      it "deletes all comments associated with a thread when called on the thread" do
        delete "/api/v1/commentables/questions/1"      
        last_response.should be_ok
        CommentThread.count.should == 0
        Comment.count.should == 0
      end
      it "deletes the comment and all sub comments when called on the comment" do
        comment_thread = CommentThread.first
        comment = comment_thread.root_comments.first
        delete "/api/v1/comments/#{comment.id}"
        last_response.should be_ok
        comment_thread.root_comments.count.should == 1
        comment_thread.comments.count.should == 2
        comment_thread.root_comments.first.title.should == "top 1"
        comment_thread.root_comments.first.children.first.title.should == "comment title 1"
      end
      it "should not delete the super comment" do
        comment_thread = CommentThread.first
        comment = comment_thread.super_comment
        delete "/api/v1/comments/#{comment.id}"
        last_response.status.should == 400
      end
    end
    describe "PUT on /api/v1/comments/comment_id" do
      before :each do
        comment_thread = CommentThread.create! :commentable_type => "questions", :commentable_id => 1
        comment_thread.root_comments.create :body => "top comment", :title => "top 0", :user_id => 1, :course_id => 1, :comment_thread_id => comment_thread.id
      end
      it "should update body and title" do
        comment = CommentThread.first.comments.first
        put "/api/v1/comments/#{comment.id}", :body => "new body", :title => "new title"
        last_response.should be_ok
        comment = CommentThread.first.comments.first
        comment.body.should == "new body"
        comment.title.should == "new title"
      end
      it "should not update the super comment" do
        comment = CommentThread.first.super_comment
        put "/api/v1/comments/#{comment.id}", :body => "new body", :title => "new title"
        last_response.status.should == 400
      end
      it "should not update user_id nor course_id" do
        comment = CommentThread.first.comments.first
        put "/api/v1/comments/#{comment.id}", :user_id => 100, :course_id => 100
        last_response.should be_ok
        comment = CommentThread.first.comments.first
        comment.user_id.should == 1
        comment.course_id.should == 1
      end
    end
  end
  describe "votings" do
    before :each do      
      CommentThread.delete_all
      Comment.delete_all
      Vote.delete_all
    end
    describe "PUT on /api/v1/votes/comments/:comment_id/users/:user_id" do
      before :each do
        CommentThread.create! :commentable_type => "questions", :commentable_id => 1
        CommentThread.first.root_comments.create :body => "top comment", :title => "top", :user_id => 1, :course_id => 1
      end
      it "votes up on a comment" do
        comment = CommentThread.first.comments.first
        put "/api/v1/votes/comments/#{comment.id}/users/1", :value => "up"
        last_response.should be_ok
        vote = Vote.first
        vote.should_not be_nil
        vote.user_id.should == 1
        vote.comment_id.should == comment.id
        vote.value.should == "up"
      end
      it "votes down on a comment" do
        comment = CommentThread.first.comments.first
        put "/api/v1/votes/comments/#{comment.id}/users/1", :value => "down"
        last_response.should be_ok
        vote = Vote.first
        vote.should_not be_nil
        vote.user_id.should == 1
        vote.comment_id.should == comment.id
        vote.value.should == "down"
      end
      it "rejects invalid vote value" do
        comment = CommentThread.first.comments.first
        put "/api/v1/votes/comments/#{comment.id}/users/1", :value => "up_or_down"
        last_response.status.should == 400
      end
      it "rejects nonexisted comment id" do
        comment = CommentThread.first.comments.first
        put "/api/v1/votes/comments/#{comment.id ** 2}/users/1", :value => "up"
        last_response.status.should == 400
      end
      it "change vote on comment" do
        comment = CommentThread.first.comments.first
        Vote.create! :value => "up", :user_id => 1, :comment_id => comment.id
        put "/api/v1/votes/comments/#{comment.id}/users/1", :value => "down"
        last_response.should be_ok
        Vote.first.value.should == "down"
      end
    end
    describe "DELETE on /api/v1/votes/comments/:comment_id/users/:user_id" do
      before :each do
        CommentThread.create! :commentable_type => "questions", :commentable_id => 1
        CommentThread.first.root_comments.create :body => "top comment", :title => "top", :user_id => 1, :course_id => 1, :comment_thread_id => CommentThread.first.id
      end
      it "deletes vote" do
        comment = CommentThread.first.comments.first 
        Vote.create! :value => "up", :user_id => 1, :comment_id => comment.id
        delete "/api/v1/votes/comments/#{comment.id}/users/1"
        last_response.should be_ok
        Vote.count.should == 0
      end
      it "returns 400 for nonexisted vote" do
        comment = CommentThread.first.comments.first 
        delete "/api/v1/votes/comments/#{comment.id}/users/1"
        last_response.status.should == 400
      end
    end
  end
end
