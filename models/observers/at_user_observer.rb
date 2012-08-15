require 'set'

class AtUserObserver < Mongoid::Observer
  observe :comment, :comment_thread

  def after_create(content)
    self.class.delay.process_at_notifications(content)
  end

  def self.process_at_notifications(content)
    text = content.body

    content_type = content.respond_to?(:title) ? :thread : :comment
    text = content.title + "\n\n" + text if content_type == :thread

    at_positions = self.get_valid_at_position_list text 
    prev_at_positions = content.at_position_list

    content.update_attributes!(at_position_list: at_positions)

    prev_user_ids = prev_at_positions.map { |x| x[:user_id] }.to_set
    current_user_ids = at_positions.map { |x| x[:user_id] }.to_set

    new_user_ids = current_user_ids - prev_user_ids

    if content_type == :thread
      thread_title = content.title
      thread_id = content.id
      commentable_id = content.commentable_id
    else
      thread_title = content.comment_thread.title
      thread_id = content.comment_thread.id
      commentable_id = content.comment_thread.commentable_id
    end

    unless new_user_ids.empty?

      notification = Notification.new(
        notification_type: "at_user",
        info: {
          comment_id: (content.id if content_type == :comment),
          content_type: content_type,
          thread_title: thread_title,
          thread_id: thread_id,
          actor_username: content.author_with_anonymity(:username),
          actor_id: content.author_with_anonymity(:id),
          commentable_id: commentable_id,
        }
      )
      receivers = new_user_ids.map { |id| User.find(id) }
      receivers.delete(content.author)
      notification.receivers << receivers
      notification.save!
    end
  end

private

  AT_NOTIFICATION_REGEX = /(?<=^|\s)(@[A-Za-z0-9_]+)(?!\w)/

  def self.get_marked_text(text)
    counter = -1
    text.gsub AT_NOTIFICATION_REGEX do
      counter += 1
      "#{$1}_#{counter}"
    end
  end

  def self.get_at_position_list(text)
    list = []
    text.gsub AT_NOTIFICATION_REGEX do
      parts = $1.rpartition('_')
      username = parts.first[1..-1]
      user = User.where(username: username).first
      if user
        list << { position: parts.last.to_i, username: parts.first[1..-1], user_id: user.id }
      end
    end
    list
  end

  def self.get_valid_at_position_list(text)
    html = Nokogiri::HTML(RDiscount.new(self.get_marked_text(text)).to_html)
    html.xpath('//code').each do |c|
      c.children = ''
    end
    self.get_at_position_list html.to_s
  end
end
