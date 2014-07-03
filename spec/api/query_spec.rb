require 'spec_helper'

describe "app" do

  before (:each) { set_api_key_header }

  let(:author) { create_test_user(1) }
  describe "thread search" do
    describe "GET /api/v1/search/threads" do
      it "returns thread with query match" do
        commentable = Commentable.new("question_1")

        random_string = (0...8).map{ ('a'..'z').to_a[rand(26)] }.join

        thread = CommentThread.new(title: "Test title", body: random_string, course_id: "1", commentable_id: commentable.id)
        thread.thread_type = :discussion
        thread.author = author
        thread.save!

        sleep 3

        get "/api/v1/search/threads", text: random_string
        last_response.should be_ok
        threads = parse(last_response.body)['collection']
        check_thread_result_json(nil, thread, threads.select{|t| t["id"] == thread.id.to_s}.first)
      end

    end
  end

  describe "comment search" do
    describe "GET /api/v1/search/threads" do
      it "returns thread with comment query match" do
        commentable = Commentable.new("question_1")

        random_string = (0...8).map{ ('a'..'z').to_a[rand(26)] }.join

        thread = CommentThread.new(title: "Test title", body: "elephant otter", course_id: "1", commentable_id: commentable.id)
        thread.thread_type = :discussion
        thread.author = author
        thread.save!

        sleep 3

        comment = Comment.new(body: random_string, course_id: "1", commentable_id: commentable.id)
        comment.author = author
        comment.comment_thread = thread
        comment.save!

        sleep 1

        get "/api/v1/search/threads", text: random_string
        last_response.should be_ok
        threads = parse(last_response.body)['collection']
        check_thread_result_json(nil, thread, threads.select{|t| t["id"] == thread.id.to_s}.first)
      end
    end
  end
end
