class PostTopicObserver < Mongoid::Observer
  observe :comment_thread

  def after_create(comment_thread)
    self.class.delay.generate_notifications(comment_thread)
  end
  
  def self.generate_notifications(comment_thread)
    if comment_thread.commentable.subscribers or (author.followers if not anonymous)
      notification = Notification.new(
        notification_type: "post_topic",
        info: {
          commentable_id: comment_thread.commentable_id,
          #commentable_type: commentable.commentable_type,
          thread_id: comment_thread.id,
          thread_title: comment_thread.title,
          actor_username: (comment_thread.author.username if not comment_thread.anonymous),
        },
      )
      notification.actor = comment_thread.author if not comment_thread.anonymous
      notification.target = comment_thread
      receivers = comment_thread.commentable.subscribers
      if not comment_thread.anonymous
        receivers = (receivers + comment_thread.author.followers).uniq_by(&:id)
      end
      receivers.delete(comment_thread.author)
      notification.receivers << receivers
      notification.save!
    end
  end
end
