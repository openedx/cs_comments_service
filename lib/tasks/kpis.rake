require 'rest_client'
roots = {}
roots['development'] = "http://localhost:8000"
roots['test'] = "http://localhost:8000"
roots['production'] = "http://edx.org"
roots['staging'] = "http://stage.edx.org"
ROOT = roots[ENV['SINATRA_ENV']]

namespace :kpis do

  task :prolific => :environment do
    #USAGE
    #SINATRA_ENV=development rake kpis:prolific
    #or
    #SINATRA_ENV=development bundle exec rake kpis:prolific

    courses = Content.all.distinct("course_id")
    puts "\n\n*********************************************************************"
    puts "  Users who have created the most forum content on edX (#{Date.today})      "
    puts "*********************************************************************\n\n"

    courses.each do |c|
      contributors = Content.prolific_metric({"course_id" => c}, 10)
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
    #SINATRA_ENV=development bundle exec rake kpis:starters

    courses = Content.all.distinct("course_id")
    puts "\n\n*********************************************************************"
    puts "  Users who have started the most threads on edX (#{Date.today})      "
    puts "*********************************************************************\n\n"

    courses.each do |c|
      contributors = Content.prolific_metric({"course_id" => c, "_type" => "CommentThread"}, 10)
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
    #SINATRA_ENV=development bundle exec rake kpis:ppu

    courses = Content.all.distinct("course_id")
    puts "\n\n*********************************************************************"
    puts "Average threads per contributing user per course on edX (#{Date.today})      "
    puts "*********************************************************************\n\n"

    courses.each do |c|
      #first, get all the users who have contributed
      contributors = Content.prolific_metric({"course_id" => c}, 10)
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

  task :epu => :environment do
    #USAGE
    #SINATRA_ENV=development rake kpis:epu
    #or
    #SINATRA_ENV=development bundle exec rake kpis:epu

    courses = Content.all.distinct("course_id")
    puts "\n\n*****************************************************************************************************************"
    puts "Average contributions (votes, threads, or comments) per contributing user per course on edX (#{Date.today})      "
    puts "*********************************************************************************************************************\n\n"

    courses.each do |c|
      #first, get all the users who have contributed
      summary = Content.summary({"course_id" => c})
      total_users = summary["contributor_count"]
      total_activity = summary['thread_count']
      total_activity += summary['comment_count']
      total_activity += summary['vote_count']
      ratio = total_activity.to_f / total_users.to_f


      puts c
      puts "*********************"
      puts "Total Threads: #{summary['thread_count']}"
      puts "Total Comments: #{summary['comment_count']}"
      puts "Total Votes: #{summary['vote_count']}\n\n"
      puts "Total Users: #{summary['contributor_count']}"
      puts "Total Engagements: #{total_activity}\n\n"
      puts "Average Engagement Per Engaging User: #{ratio}\n\n\n  "

    end
  end

  task :orphans => :environment do
    #USAGE
    #SINATRA_ENV=development rake kpis:orphans
    #or
    #SINATRA_ENV=development bundle exec rake kpis:orphans

    courses = Content.all.distinct("course_id")
    puts "\n\n****************************************************"
    puts "thread reply rate per course on edX (#{Date.today})      "
    puts "****************************************************\n\n"

    courses.each do |c|
      #first, get all the users who have contributed
      threads = Content.where({"course_id" => c, "_type" => "CommentThread"})
      orphans = Content.where({"course_id" => c, "_type" => "CommentThread", "comment_count" => 0})

      ratio = orphans.count.to_f / threads.count.to_f

      puts c
      puts "*********************"
      puts "Total Threads: #{threads.count}"
      puts "Total Orphaned Threads: #{orphans.count}"
      if threads.count > 0
        puts "Orphan Ratio: #{(ratio*1000).round.to_f/10.0}%"
      end
      puts "\n\n\n"
    end
  end
end
