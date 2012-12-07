require 'rest_client'
roots = {}
roots['development'] = "http://localhost:8000"
roots['test'] = "http://localhost:8000"
roots['production'] = "http://edx.org"
ROOT = roots[ENV['SINATRA_ENV']]

namespace :flags do
  task :flagged => :environment do
    flagged = Content.flagged
    flagged.each do |f|
      if f.attributes.include? "comment_thread_id"
        id = f.comment_thread_id
      else
        id = f.id
      end
      puts "#{ROOT}/courses/#{f.course_id}/discussion/forum/#{f.commentable_id}/threads/#{id}"
    end

  end
end
