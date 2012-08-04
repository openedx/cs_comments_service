class PostReplyObserver < Mongoid::Observer
  observe :comment

  def after_create(comment)
    self.class.delay.generate_notifications(comment)
  end
    
  def self.generate_notifications(comment)
    if comment.comment_thread.subscribers or (comment.author.followers if not comment.anonymous)
      notification = Notification.new(
        notification_type: "post_reply",
        info: {
          thread_id: comment.comment_thread.id,
          thread_title: comment.comment_thread.title,
          comment_id: comment.id,
          commentable_id: comment.comment_thread.commentable_id,
          actor_username: (comment.author.username if not comment.anonymous),
        },
      )
      notification.actor = comment.author if not comment.anonymous
      notification.target = comment
      receivers = comment.comment_thread.subscribers
      if not comment.anonymous
        receivers = (receivers + comment.author.followers).uniq_by(&:id)
      end
      receivers.delete(comment.author)
      notification.receivers << receivers
      notification.save!
    end
  end
end
