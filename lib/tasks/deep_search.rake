require 'rest_client'
roots = {}
roots['development'] = "http://localhost:8000"
roots['test'] = "http://localhost:8000"
roots['production'] = "http://edx.org"
roots['staging'] = "http://stage.edx.org"
ROOT = roots[ENV['SINATRA_ENV']]

namespace :deep_search do

  task :performance => :environment do
    #USAGE
    #SINATRA_ENV=development rake kpis:prolific
    #or
    #SINATRA_ENV=development bundle exec rake kpis:prolific

    #create comment and thread bodies
    bodies = []
    
    50.times do |i|
      bodies <<  (0...8).map{ ('a'..'z').to_a[rand(26)] }.join
    end

    parents = CommentThread.limit(100)
    #now create comments and threads with hits

    puts "Manufacturing Threads"
    100.times do |j|
      (1..5).to_a.sample.times do |i|
        c = CommentThread.new
        c.course_id = 'sample course'
        c.title = 'sample title'
        c.commentable_id = 'sample commetable'
        c.body = bodies.sample
        c.author = 1
        c.save
      end
    end

    puts "Manufacturing Comments"
    100.times do |j|
      (1..5).to_a.sample.times do |i|
        c = Comment.new
        c.course_id = 'sample course'
        c.body = bodies.sample
        c.comment_thread_id = parents.sample.id
        c.author = 1
        c.save
      end
    end

    sort_keys = %w[date activity votes comments]
    sort_order = "desc"

    #set the sinatra env to test to avoid 401'ing
    set :environment, :test

    start_time = Time.now
    puts "Starting test at #{start_time}"
    1000.times do |i|
      query_params = { course_id: "1", sort_key: sort_keys.sample, sort_order: sort_order, page: 1, per_page: 5, text: bodies.sample }
      RestClient.get "#{PREFIX}/threads", params: query_params
    end
    end_time = Time.now
    puts "Ending test at #{end_time}"
    puts "Total Time: #{(end_time - start_time).to_f} seconds"

  end
  
end
