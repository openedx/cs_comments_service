require 'rest_client'
roots = {}
roots['development'] = "http://localhost:8000"
roots['test'] = "http://localhost:8000"
roots['production'] = "http://edx.org"
ROOT = roots[ENV['SINATRA_ENV']]

namespace :flags do


  #USAGE
  #SINATRA_ENV=development rake flags:flagged

  task :flagged => :environment do
    flagged = Content.flagged

    courses = {}

    flagged.each do |f|

      if not courses[f.course_id]
        courses[f.course_id] = []
      end

      courses[f.course_id] << f
    end

    courses.each do |k,v|
      puts "#{k.upcase}"
      puts "****************"
      v.each do |f|
        puts "#{ROOT}/courses/#{f.course_id}/discussion/forum/#{f.commentable_id}/threads/#{f.comment_thread_id} (#{f.class})"
      end
      puts "\n\n\n\n"
    end

  end
end
