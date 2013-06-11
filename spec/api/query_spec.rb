require 'spec_helper'

describe "app" do
	describe "search" do

		describe "GET /api/v1/search/threads" do
			it "returns thread with query match" do
				user = User.find 1
				if not user
					user = create_test_user(1)
				end
				commentable = Commentable.new("question_1")

				thread = CommentThread.new(title: "Test title", body: "otter", course_id: "1", commentable_id: commentable.id)
				thread.author = user
				thread.save!

				puts "thread id is #{thread.id}"

				get "/api/v1/search/threads", text: "otter"
				last_response.should be_ok
				threads = parse(last_response.body)['collection']
				puts "threads: #{threads.collect{|t| t['id']}}"
				threads.select{|t| t["id"].to_s == thread.id.to_s}.first.should_not be_nil
			end
		end
	end
end
