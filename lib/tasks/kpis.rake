require 'rest_client'
roots = {}
roots['development'] = "http://localhost:8000"
roots['test'] = "http://localhost:8000"
roots['production'] = "http://edx.org"
ROOT = roots[ENV['SINATRA_ENV']]

namespace :kpis do


  
  
  task :prolific => :environment do
    #USAGE
    #SINATRA_ENV=development rake kpis:prolific
    #or
    #SINATRA_ENV=development bundle exed rake kpis:prolific
    
    courses = Content.all.distinct("course_id")
      puts "\n\n*********************************************************************"
      puts "  Users who have created the most forum content on edX (#{Date.today})      "
      puts "*********************************************************************\n\n"
    
    courses.each do |c|
      contributors = Content.prolific_metric({"course_id" => c})
      #now output
      puts c
      puts "*********************"
      contributors.each do |p|
        url = ROOT + "/courses/#{c}/discussion/forum/users/#{p['_id']}"
        count_string = "#{p['value'].to_i} contributions:".rjust(25)
        puts "#{count_string} #{url} "
      end      
      puts "\n"            

    end
  end
  
  
  task :starters => :environment do
    #USAGE
    #SINATRA_ENV=development rake kpis:starters
    #or
    #SINATRA_ENV=development bundle exed rake kpis:startersgimp

    courses = Content.all.distinct("course_id")
      puts "\n\n*********************************************************************"
      puts "  Users who have started the most threads on edX (#{Date.today})      "
      puts "*********************************************************************\n\n"
    
    courses.each do |c|
      contributors = Content.prolific_metric({"course_id" => c, "_type" => "CommentThread"})
      #now output
      puts c
      puts "*********************"
      contributors.each do |p|
        url = ROOT + "/courses/#{c}/discussion/forum/users/#{p['_id']}"
        count_string = "#{p['value'].to_i} contributions:".rjust(25)
        puts "#{count_string} #{url} "
      end      
      puts "\n"            

    end
  end
end
