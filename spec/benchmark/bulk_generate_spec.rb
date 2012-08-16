require 'spec_helper'

Mongoid.configure do |config|
  config.connect_to "cs_comments_service_bulk_test"
end

describe "app" do
  describe "benchmark" do
    it "bulk generate" do
      [Comment, CommentThread, User, Notification, Subscription].each(&:delete_all).each(&:create_indexes)
      
      Delayed::Backend::Mongoid::Job.create_indexes

      COMMENTABLES = 20
      USERS = 20
      THREADS = 200
      TOP_COMMENTS = 1000
      SUB_COMMENTS = 1000
      VOTES = 10000
      TAGS = 1000

      Benchmark.bm(31) do |x|
        x.report "create users" do
          (1..USERS).each do |user_id|
            post "/api/v1/users", id: user_id, username: "user#{user_id}", email: "user#{user_id}@test.com"
          end
        end

        x.report "create new threads" do
          THREADS.times do
            post "/api/v1/question_#{rand(COMMENTABLES).to_s}/threads", \
                              title: "Interesting question", body: "cool", anonymous: false, \
                              course_id: "1", user_id: (rand(USERS) + 1).to_s, \
                              tags: (1..5).map{|x| "tag#{rand(TAGS)}"}.join(",")
          end
        end

        comment_thread_ids = CommentThread.all.to_a.map(&:id)

        x.report("create top comments") do
          TOP_COMMENTS.times do
            post "/api/v1/threads/#{comment_thread_ids.sample}/comments", \
                              body: "lalala", anonymous: false,
                              course_id: "1", user_id: (rand(USERS) + 1).to_s
          end
        end

        top_comment_ids = Comment.all.to_a.map(&:id)

        x.report("create sub comments") do
          SUB_COMMENTS.times do
            post "/api/v1/comments/#{top_comment_ids.sample}", \
                              body: "lalala", anonymous: false,
                              course_id: "1", user_id: (rand(USERS) + 1).to_s
          end
        end

        x.report("create votes") do
          VOTES.times do
            put "/api/v1/threads/#{comment_thread_ids.sample}", user_id: (rand(USERS) + 1).to_s, value: [:up, :down].sample
            put "/api/v1/threads/#{top_comment_ids.sample}", user_id: (rand(USERS) + 1).to_s, value: [:up, :down].sample
          end
        end
      end
    end
  end
end
