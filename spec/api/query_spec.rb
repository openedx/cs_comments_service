require 'spec_helper'

describe "app" do
	describe "thread search" do
		describe "GET /api/v1/search/threads" do
			it "returns thread with query match" do
				user = User.find 1
				if user.nil?
					user = create_test_user(1)
				end

				commentable = Commentable.new("question_1")

				random_string = (0...8).map{ ('a'..'z').to_a[rand(26)] }.join

				thread = CommentThread.new(title: "Test title", body: random_string, course_id: "1", commentable_id: commentable.id)
				thread.author = user
				thread.save!

				sleep 3

				get "/api/v1/search/threads", text: random_string
				last_response.should be_ok
				threads = parse(last_response.body)['collection']
				check_thread_result(nil, thread, threads.select{|t| t["id"] == thread.id.to_s}.first, false, true)
			end

		end
	end

	describe "comment search" do
		describe "GET /api/v1/search/threads" do
			it "returns thread with comment query match" do
				user = User.find 1
				if user.nil?
					user = create_test_user(1)
				end
				
				commentable = Commentable.new("question_1")

				random_string = (0...8).map{ ('a'..'z').to_a[rand(26)] }.join

				thread = CommentThread.new(title: "Test title", body: "elephant otter", course_id: "1", commentable_id: commentable.id)
				thread.author = user
				thread.save!

				sleep 3

				comment = Comment.new(body: random_string, course_id: "1", commentable_id: commentable.id)
				comment.author = user
				comment.comment_thread = thread
				comment.save!

				sleep 1

				get "/api/v1/search/threads", text: random_string
				last_response.should be_ok
				threads = parse(last_response.body)['collection']
				check_thread_result(nil, thread, threads.select{|t| t["id"] == thread.id.to_s}.first, false, true)
			end
		end
	end
end
