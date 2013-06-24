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


  def self.get_notification_email_bodies start_date_time, end_date_time, user_ids
  end


  def self.test_results
    start_time = Time.now - 100.days
    end_time = Time.now - 99.days

    #find some content in the range

    content = Content.by_date_range start_time, end_time
    thread_ids = content.collect{|c| c.comment_thread_id}.uniq
    subscriptions = Subscription.where(:source_id.in => thread_ids)
    user_ids = subscriptions.sample(10).collect{|s| s.subscriber_id}

    test_results = self.by_date_range start_time, end_time, user_ids
  end

  def self.by_date_range start_date_time, end_date_time, user_ids  
    #given a date range and a user, find all of the notifiable content
    #key by thread id, and return notification messages for each user

    

    #first, find the subscriptions for the users
    subscriptions = Subscription.where(:subscriber_id.in => user_ids)

    #get the thhread ids
    thread_ids = subscriptions.collect{|t| t.source_id}.uniq

    #find all the comments
    comments = Comment.by_date_range_and_thread_ids start_date_time, end_date_time, thread_ids

    #and get the threads too, b/c we'll need them for the title

    threads = CommentThread.where(:_id.in => thread_ids)

    #now build a thread to users subscription map
    subscriptions_map = {}
    subscriptions.each do |s|
      if not subscriptions_map.keys.include? s.source_id.to_s
        subscriptions_map[s.source_id.to_s] = []
      end
      subscriptions_map[s.source_id] << s.subscriber_id
    end

    #notification map will be user => course => thread => [comment bodies]

    notification_map = {}

    comments.each do |c|
      user_ids = subscriptions_map[c.comment_thread_id.to_s]
      user_ids.each do |u|
        if not notification_map.keys.include? u
          notification_map[u] = {}
        end

        if not notification_map[u].keys.include? c.course_id
          notification_map[u][c.course_id] = {}
        end

        if not notification_map[u][c.course_id].include? c.comment_thread_id.to_s
          notification_map[u][c.course_id][c.comment_thread_id.to_s] = []
        end

         notification_map[u][c.course_id][c.comment_thread_id.to_s] << c.body.truncate(CommentService.config["email_digest_comment_length"])

      end
    end

    notification_map

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
