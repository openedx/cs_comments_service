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
          actor_username: comment.author_with_anonymity(:username),
        },
      )
      notification.actor = comment.author_with_anonymity
      notification.target = comment
      receivers = (comment.comment_thread.subscribers + comment.author_with_anonymity(:followers, [])).uniq_by(&:id)
      receivers.delete(comment.author)
      notification.receivers << receivers
      notification.save!
    end
  end
end
