require 'rest_client'

namespace :benchmark do
  task :bulk_generate => :environment do

    seed_config = YAML.load_file("config/benchmark.yml").with_indifferent_access

    COMMENTABLES = seed_config[:seed_size][:commentables]
    USERS = seed_config[:seed_size][:users]
    THREADS = seed_config[:seed_size][:threads]
    TOP_COMMENTS = seed_config[:seed_size][:top_comments]
    SUB_COMMENTS = seed_config[:seed_size][:sub_comments]
    VOTES = seed_config[:seed_size][:votes]
    TAGS = seed_config[:seed_size][:tags]

    PREFIX = "http://localhost:4567/api/v1"

    Benchmark.bm(31) do |x|
      
      RestClient.get "#{PREFIX}/clean"

      x.report "create users via api" do
        (1..USERS).each do |user_id|
          data = { id: user_id, username: "user#{user_id}", email: "user#{user_id}@test.com" }
          RestClient.post "#{PREFIX}/users", data
        end
      end

      x.report "create new threads via api" do
        (1..THREADS).each do |t|
          data = {title: "Interesting question", body: "cool", anonymous: false, \
                            course_id: "1", user_id: (rand(USERS) + 1).to_s, \
                            tags: (1..5).map{|x| "tag#{rand(TAGS)}"}.join(",")}

          RestClient.post "#{PREFIX}/question_#{rand(COMMENTABLES).to_s}/threads", data
                            
        end
      end

      comment_thread_ids = CommentThread.all.to_a.map(&:id)

      x.report("create top comments via api") do
        TOP_COMMENTS.times do
          data = {body: "lalala", anonymous: false,
                            course_id: "1", user_id: (rand(USERS) + 1).to_s}
          RestClient.post "#{PREFIX}/threads/#{comment_thread_ids.sample}/comments", data
                            
        end
      end

      top_comment_ids = Comment.all.to_a.map(&:id)

      x.report("create sub comments") do
        SUB_COMMENTS.times do
          data = {body: "lalala", anonymous: false,
                            course_id: "1", user_id: (rand(USERS) + 1).to_s}
          RestClient.post "#{PREFIX}/comments/#{top_comment_ids.sample}", data
                            
        end
      end

      x.report("create votes") do
        VOTES.times do
          data = {user_id: (rand(USERS) + 1).to_s, value: [:up, :down].sample}
          RestClient.put "#{PREFIX}/threads/#{comment_thread_ids.sample}/votes", data
          RestClient.put "#{PREFIX}/comments/#{top_comment_ids.sample}/votes", data
        end
      end
    end
  end
end
