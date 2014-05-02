require 'rest_client'

PREFIX = "http://localhost:4567/api/v1"

namespace :benchmark do
  task :bulk_generate => :environment do

    seed_size_config = YAML.load_file("config/benchmark.yml").with_indifferent_access[:seed_size]

    COMMENTABLES = seed_size_config[:commentables]
    USERS        = seed_size_config[:users]
    THREADS      = seed_size_config[:threads]
    TOP_COMMENTS = seed_size_config[:top_comments]
    SUB_COMMENTS = seed_size_config[:sub_comments]
    VOTES        = seed_size_config[:votes]
    TAGS         = seed_size_config[:tags]

    Benchmark.bm(31) do |x|
      
      RestClient.get "#{PREFIX}/clean"

      x.report "create users" do
        (1..USERS).each do |user_id|
          data = { id: user_id, username: "user#{user_id}" }
          RestClient.post "#{PREFIX}/users", data
        end
      end

      x.report "create new threads" do
        (1..THREADS).each do |t|
          data = {title: Faker::Lorem.sentence(6) + " token#{rand(10)} token#{rand(10)}", body: Faker::Lorem.paragraphs.join("\n\n") + " token#{rand(10)} token#{rand(10)}", anonymous: false, \
                            course_id: "1", user_id: (rand(USERS) + 1).to_s, \
                            tags: (1..5).map{|x| "tag#{rand(TAGS)}"}.join(",")}

          RestClient.post "#{PREFIX}/question_#{rand(COMMENTABLES).to_s}/threads", data
                            
        end
      end

      comment_thread_ids = CommentThread.all.to_a.map(&:id)

      x.report("create top comments") do
        TOP_COMMENTS.times do
          data = {body: Faker::Lorem.paragraphs.join("\n\n") + " token#{rand(10)} token#{rand(10)}", anonymous: false,
                            course_id: "1", user_id: (rand(USERS) + 1).to_s}
          RestClient.post "#{PREFIX}/threads/#{comment_thread_ids.sample}/comments", data
                            
        end
      end

      top_comment_ids = Comment.all.to_a.map(&:id)

      x.report("create sub comments") do
        SUB_COMMENTS.times do
          data = {body: Faker::Lorem.paragraphs.join("\n\n") + " token#{rand(10)} token#{rand(10)}", anonymous: false,
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
  task :bulk_query => :environment do 

    query_amount_config = YAML.load_file("config/benchmark.yml").with_indifferent_access[:query_amount]
    
    COURSE_THREAD_QUERY = query_amount_config[:course_thread_query]

    Benchmark.bm(31) do |x|
      sort_keys = %w[date activity votes comments]
      sort_order = "desc"

      x.report("querying threads in a course") do
        
        (1..COURSE_THREAD_QUERY).each do |seed|
          query_params = { course_id: "1", sort_key: sort_keys[seed % 4], sort_order: sort_order, page: seed % 5 + 1, per_page: 5 }
          RestClient.get "#{PREFIX}/threads", params: query_params
        end
      end
      x.report("searching threads in a course") do
        
        (1..COURSE_THREAD_QUERY).each do |seed|
          query_params = { course_id: "1", text: "token#{seed % 10} token#{(seed * seed) % 10}", sort_key: sort_keys[seed % 4], sort_order: sort_order, page: seed % 5 + 1, per_page: 5 }
          RestClient.get "#{PREFIX}/search/threads", params: query_params
        end
      end
    end
  end
end
