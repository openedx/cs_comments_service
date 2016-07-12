require 'factory_girl'

namespace :db do
  FactoryGirl.find_definitions

  def create_test_user(id)
    User.create!(external_id: id, username: "user#{id}")
  end

  task :init => :environment do
    puts 'recreating indexes...'
    [Comment, CommentThread, User, Notification, Subscription, Activity, Delayed::Backend::Mongoid::Job].each(&:remove_indexes).each(&:create_indexes)
    puts 'finished'
  end

  task :clean => :environment do
    Comment.delete_all
    CommentThread.delete_all
    User.delete_all
    Notification.delete_all
    Subscription.delete_all
  end

  THREADS_PER_COMMENTABLE = 20
  TOP_COMMENTS_PER_THREAD = 3
  ADDITIONAL_COMMENTS_PER_THREAD = 5

  COURSE_ID = 'MITx/6.002x/2012_Fall'

  def generate_comments_for(commentable_id, num_threads=THREADS_PER_COMMENTABLE, num_top_comments=TOP_COMMENTS_PER_THREAD, num_subcomments=ADDITIONAL_COMMENTS_PER_THREAD)
    level_limit = CommentService.config['level_limit']


    users = User.all.to_a

    puts "Generating threads and comments for #{commentable_id}..."

    threads = []
    top_comments = []
    additional_comments = []

    num_threads.times do
      inner_top_comments = []

      # Create a new thread
      comment_thread = FactoryGirl::create(:comment_thread, commentable_id: commentable_id, author: users.sample, course_id: COURSE_ID)
      threads << comment_thread

      # Subscribe a few users to the thread
      users.sample(3).each { |user| user.subscribe(comment_thread) }

      # Create a few top-level comments for the thread
      (1 + rand(num_top_comments)).times do
        endorsed = [true, false].sample
        comment = FactoryGirl::create(:comment, author: users.sample, comment_thread: comment_thread, endorsed: endorsed, course_id: COURSE_ID)
        top_comments << comment
        inner_top_comments << comment
      end

      # Created additional nested comments
      parent_comments = inner_top_comments
      (level_limit-1).times do
        current_level_comments = []
        (1 + rand(num_subcomments)).times do
          parent = parent_comments.sample
          endorsed = [true, false].sample
          child = FactoryGirl::create(:comment, author: users.sample, parent: parent, endorsed: endorsed)
          current_level_comments << child
        end
        parent_comments = current_level_comments
      end
    end

    puts 'voting'

    (threads + top_comments + additional_comments).each do |c|
      users.each do |user|
        user.vote(c, [:up, :down].sample)
      end
    end
    puts 'finished'
  end


  task :generate_comments, [:commentable_id, :num_threads, :num_top_comments, :num_subcomments] => :environment do |t, args|
    args.with_defaults(num_threads: THREADS_PER_COMMENTABLE,
                       num_top_comments: TOP_COMMENTS_PER_THREAD,
                       num_subcomments: ADDITIONAL_COMMENTS_PER_THREAD)
    generate_comments_for(args[:commentable_id], args[:num_threads], args[:num_top_comments], args[:num_subcomments])

  end

  task :seed => [:environment, :clean] do
    Tire.index 'comment_threads' do
      delete
    end
    CommentThread.create_elasticsearch_index

    beginning_time = Time.now

    (1..10).map { |id| create_test_user(id) }
    generate_comments_for('video_1')
    generate_comments_for('lab_1')
    generate_comments_for('lab_2')

    end_time = Time.now

    puts "Number of comments generated: #{Comment.count}"
    puts "Number of comment threads generated: #{CommentThread.count}"

    puts "Time elapsed #{(end_time - beginning_time)*1000} milliseconds"

  end

  task :add_anonymous_to_peers => :environment do
    Content.collection.find(:anonymous_to_peers => nil).update_all({'$set' => {anonymous_to_peers: false}})
  end

end
