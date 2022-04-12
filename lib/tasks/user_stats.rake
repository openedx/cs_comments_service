require 'logger'
namespace :user_stats do

  logger = Logger.new(STDOUT)

  desc 'Updates discussion stats for users in a course'
  task :update_stats, [:course_id] => :environment do |t, args|
    if args[:course_id]
      updated_users = update_all_users_in_course args[:course_id]
      logger.info "Updated stats for #{updated_users.length} users"
    else
      abort "Course id is required"
    end     
  end

end
