class PostTopicObserver < Mongoid::Observer
  observe :comment_thread

  def after_create(comment_thread)
    self.class.delay.generate_notifications(comment_thread)
  end
  
  def self.generate_notifications(comment_thread)
    activity = Activity.new
    activity.happend_at = comment_thread.created_at
    activity.anonymous = (comment_thread.anonymous || comment_thread.anonymous_to_peers)
    activity.actor = comment_thread.author
    #activity.target_id = comment_thread.commentable.id
    #activity.target_type = comment_thread.commentable._type
    activity.activity_type = "post_topic"
    activity.save!
    if comment_thread.commentable.subscribers or (author.followers if not activity.anonymous)
      notification = Notification.new(
        notification_type: "post_topic",
        info: {
          commentable_id: comment_thread.commentable_id,
          thread_id: comment_thread.id,
          thread_title: comment_thread.title,
          actor_username: comment_thread.author_with_anonymity(:username),
          actor_id: comment_thread.author_with_anonymity(:id),
        },
      )
      receivers = (comment_thread.commentable.subscribers + comment_thread.author_with_anonymity(:followers, [])).uniq_by(&:id)
      receivers.delete(comment_thread.author)
      notification.receivers << receivers
      notification.save!
    end
  end
end
