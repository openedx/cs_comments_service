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
    #SINATRA_ENV=development bundle exed rake kpis:starters

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

  task :ppu => :environment do
    #USAGE
    #SINATRA_ENV=development rake kpis:ppu
    #or
    #SINATRA_ENV=development bundle exed rake kpis:ppu

    courses = Content.all.distinct("course_id")
    puts "\n\n*********************************************************************"
    puts "Average threads per contributing user per course on edX (#{Date.today})      "
    puts "*********************************************************************\n\n"

    courses.each do |c|
      #first, get all the users who have contributed
      contributors = Content.prolific_metric({"course_id" => c})
      total_users = contributors.count

      #now, get the threads

      total_threads = Content.where("_type" => "CommentThread","course_id" => c).count

      ratio = total_threads.to_f / total_users.to_f

      #now output
      puts c
      puts "*********************"
      puts "Total Threads: #{total_threads}"
      puts "Total Users: #{total_users}"
      puts "Average Thread/User: #{ratio}"
      puts "\n"

    end

    task :epu => :environment do
      #USAGE
      #SINATRA_ENV=development rake kpis:ppu
      #or
      #SINATRA_ENV=development bundle exed rake kpis:ppu

      courses = Content.all.distinct("course_id")
      puts "\n\n**************************************************************************************************************************************"
      puts "Average contributions (votes, comments, endorsements, or threads or follows) per contributing user per course on edX (#{Date.today})      "
      puts "******************************************************************************************************************************************\n\n"

      courses.each do |c|
        #first, get all the users who have contributed
        contributors = Content.prolific_metric({"course_id" => c})
        total_users = contributors.count

        #now, get the threads

        total_threads = Content.where("_type" => "CommentThread","course_id" => c).count

        ratio = total_threads.to_f / total_users.to_f

        #now output
        puts c
        puts "*********************"
        puts "Total Threads: #{total_threads}"
        puts "Total Users: #{total_users}"
        puts "Average Thread/User: #{ratio}"
        puts "\n"

      end
    end
  end


end
