require 'rest_client'
roots = {}
roots['development'] = "http://localhost:8000"
roots['test'] = "http://localhost:8000"
roots['production'] = "http://edx.org"
ROOT = roots[ENV['SINATRA_ENV']]

namespace :kpis do


  #USAGE
  #SINATRA_ENV=development rake kpis:prolific
  
  task :prolific => :environment do

    count = 10
    
    contributors = {}
    
    map =  "function(){emit(this.author_id,1)}"
    reduce  =  "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
    
    courses = Content.all.distinct("course_id")
    courses.each do |c|
      contributors[c] = []
      Content.where(course_id: c).map_reduce(map,reduce).out(replace: "results").each do |d|
        contributors[c] << d
      end
    end
    
    #now sort and limit them
    
    courses.each do |c|
      #first sort destructively
      contributors[c].sort! {|a,b| -a["value"] <=> -b["value"]}
      #then trim it
      contributors[c] = contributors[c][0..(count - 1)]
      
      #now output
      puts "\n\n\n"
      puts c
      contributors[c].each do |p|
        url = ROOT + "/courses/#{c}/discussion/forum/users/#{p['_id']}"
        count_string = "#{p['value'].to_i} contributions:".rjust(25)
        puts "#{count_string} #{url} "
      end      
      
    end  
  end
end
