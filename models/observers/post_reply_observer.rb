class PostReplyObserver < Mongoid::Observer
  observe :comment

  def after_create(comment)
    self.class.delay.generate_activity_and_notifications(comment)
  end
    
  def self.generate_activity_and_notifications(comment)

    activity = Activity.new
    activity.happend_at = comment.created_at
    activity.anonymous = (comment.anonymous || comment.anonymous_to_peers)
    activity.actor = comment.author
    activity.target = comment.comment_thread
    activity.activity_type = "post_reply"
    activity.save!

    if comment.comment_thread.subscribers or (comment.author.followers if not activity.anonymous)
      notification = Notification.new(
        notification_type: "post_reply",
        info: {
          thread_id: comment.comment_thread.id,
          thread_title: comment.comment_thread.title,
          comment_id: comment.id,
          commentable_id: comment.comment_thread.commentable_id,
          actor_username: comment.author_with_anonymity(:username),
          actor_id: comment.author_with_anonymity(:id),
        },
      )
      receivers = (comment.comment_thread.subscribers + comment.author_with_anonymity(:followers, [])).uniq_by(&:id)
      receivers.delete(comment.author)
      notification.receivers << receivers
      notification.save!
    end
  end
end
