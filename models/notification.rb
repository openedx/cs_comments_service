class Notification
  include Mongoid::Document
  include Mongoid::Timestamps

  field :notification_type, type: String
  field :info, type: Hash

  attr_accessible :notification_type, :info

  validates_presence_of :notification_type
  validates_presence_of :info

  has_and_belongs_to_many :receivers, class_name: "User", inverse_of: :notifications, autosave: true

  def to_hash(params={})
    as_document.slice(*%w[notification_type info actor_id target_id]).merge("id" => _id)
  end

  def self.by_date_range 
    #start_date_time, end_date_time
    #given a date range, find all of the notifiable content
    #key by thread id

    #first, find the content in the range
    puts "a"

    start_date_time = Time.now - 100.days
    end_date_time = Time.now - 99.days

    content = Content.by_date_range start_date_time, end_date_time
    puts "b"
    thread_ids = content.collect{|t| t.comment_thread_id}.uniq

    puts "c"
    
    #now, find all of the subscriptions to that content
    subscriptions = Subscription.where(:source_id.in => thread_ids)
    puts "d"

    #now remove content for which there are no subscriptons

    thread_ids = subscriptions.collect{|s| s.source_id}.uniq
    puts "e"

    #now remove content where thread_id is not in thread_ids

    content = content.select {|c| thread_ids.include? c.comment_thread_id.to_s} 
    puts "f"

    #we need to preload the users so we can look at their read states 
    #(there is one read state per thread that a user has read)

    user_ids = subscriptions.collect{|s| s.subscriber_id}.uniq
    puts "g"
    users = User.where(:_id.in => user_ids)
    puts "h"

    #make a user_id => User map for easy access

    user_map = {}
    users.each do |u|
      user_map[u._id.to_s] = u
    end

    #unfortunately, we need a thread map also, because we need to get the course_id 
    #because it's the key for each users read state (each user has one read state)
    #per course

    thread_map = {}
    threads = CommentThread.where(:_id.in => thread_ids)
    threads.each do |t|
      thread_map[t._id.to_s] = t
    end

puts "i"

    #now we have everything we need, so walk the subscribers, and if the user's read state last read on is less 
    #than the content created_at timestamp, add it to the notiications

    answer = {}

    content.each do |c|

      if not answer.keys.include? c.comment_thread_id.to_s
        answer[c.comment_thread_id.to_s] = {}
      end

      subscriptions.each do |s|

        #if the user has a read state for this subscription (which they should because the subscription exists)
        user = user_map[s.subscriber_id]
        begin
          read_state = user.read_states.find_by(course_id: thread_map[s.source_id].course_id)
        rescue
          read_sate = nil
        end

        #if the read state is good and the content is newer than the last time this thread was
        #read by the user
        if read_state and 
          read_state.last_read_times and 
          read_state.last_read_times[s.source_id] and 
          read_state.last_read_times[s.source_id] < c.updated_at and
          c.abuse_flaggers.empty? #only send notifications for non flagged content
          #note, there is an edge case here where if a comment is flagged as abuse, but
          #later cleared, a user may never get a notification for it, depending on timing

            #then add it to the results

            puts "adding notification"

            #but first check to see if an entry exists for this user
            if not answer[c.comment_thread_id.to_s][s.subscriber_id]
              answer[c.comment_thread_id.to_s][s.subscriber_id] = [] 
            end

            #now add the notification to the user's notification array
            answer[c.comment_thread_id.to_s][s.subscriber_id]  << [c._type, c.body, c.updated_at]

        end

      end
    end

  answer

  end

  def self.random_subscription_useful
    #find a subscription, and find out if it would have been useful to be notified
    #this is defined as there being new content since the last time the user 
    #read this thread

    #first, find a random subscription
    s = Subscription.skip(rand(Subscription.count)).first
    u = User.find s.subscriber_id
    t = CommentThread.find s.source_id

    comments = Comment.where(:comment_thread_id => t.id)

    max_date = comments.collect{|c| c.created_at}.max if comments.count > 0

    last_read_time = u.read_states.find_by(course_id: t.course_id).last_read_times[t.id.to_s]
    if comments.count > 0
    if last_read_time
      if last_read_time > max_date
        true
      else
        false
      end
    else
      nil
    end
  else
    false
  end
  end

end
