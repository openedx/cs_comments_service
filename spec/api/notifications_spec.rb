require 'spec_helper'

describe "app" do
  describe "notifications" do

    before(:each) do
      init_without_subscriptions
      set_api_key_header
    end

    def create_thread(user, options = {})
      # Create a CommentThread with the given user.
      # Can optionally specify a cohort group_id via options.
      # Returns the created CommentThread.

      commentable = Commentable.new("question_1")
      random_string = (0...8).map{ ('a'..'z').to_a[rand(26)] }.join
      thread = CommentThread.new(
        title: "Test title", body: "elephant otter", course_id: "1",
        commentable_id: commentable.id, comments_text_dummy: random_string
      )
      thread.thread_type = :discussion
      thread.author = user
      if options[:group_id]
        thread.group_id = options[:group_id]
      end
      thread.save!

      return thread
    end

    def get_thread_notification(comment_body, options = {})
      # Creates a thread and comment with the specified comment_body.
      # Can optionally specify a cohort group_id via options.
      # Calls the notifications API to retrieve the notification for the thread
      # and returns the response hash for the single comment thread within the course.
      # Keys for the returned hash: content, title, commentable_id, group_id (only present if cohorted).

      start_time = Time.now
      user = User.create(:external_id => 1,:username => "example")
      thread = create_thread(user, options)

      subscription = Subscription.create(:subscriber_id => user._id.to_s, :source_id => thread._id.to_s)

      comment = Comment.new
      comment.comment_thread_id = thread.id
      comment.body = comment_body
      comment.author_id = user.id
      comment.course_id = 'test course'
      comment.save!

      sleep 1

      end_time = Time.now

      post(
        "/api/v1/notifications",
        {
          from: CGI::escape(start_time.to_s),
          to: CGI::escape(end_time.to_s),
          user_ids: subscription.subscriber_id
        }
      )

      last_response.should be_ok
      response_hash = JSON.parse(last_response.body)
      return response_hash[user.id][comment.course_id][thread.id.to_s]
    end

    describe "POST /api/v1/notifications" do
      it "returns notifications by class and user" do
        expected_comment_body = random_string = (0..5).map{ ('a'..'z').to_a[rand(26)] }.join
        thread_notification = get_thread_notification(expected_comment_body)
        actual_comment_body = thread_notification["content"][0]["body"]
        actual_comment_body.should eq(expected_comment_body)
      end

      it "contains cohort group_id if defined" do
        thread_notification = get_thread_notification("dummy comment content", :group_id => 1974)
        thread_notification["group_id"].should be(1974)
      end

      it "does not contain cohort group_id if not defined" do
        thread_notification = get_thread_notification("dummy comment content")
        thread_notification.has_key?("group_id").should be_false
      end

      it "returns only threads subscribed to by user" do

        # first make a dummy thread and comment and a subscription
        commentable = Commentable.new("question_1")
        user = User.create(:external_id => 1,:username => "example")
        thread = create_thread(user)

        subscription = Subscription.create({:subscriber_id => user._id.to_s, :source_id => thread._id.to_s})

        comment = Comment.new(body: "dummy body text", course_id: "1", commentable_id: commentable.id)
        comment.author = user
        comment.comment_thread = thread
        comment.save!

        start_time = Date.today - 100.days

        sleep 1

        end_time = Time.now + 5.seconds

        post "/api/v1/notifications", from: CGI::escape(start_time.to_s), to: CGI::escape(end_time.to_s), user_ids: user.id

        last_response.should be_ok
        payload = JSON.parse last_response.body
        courses = payload[user.id.to_s]
        thread_ids = []
        courses.each do |k,v|
            v.each do |kk,vv|
                thread_ids << kk
            end
        end
        #now make sure the threads are a subset of the user's subscriptions
        subscriptions = Subscription.where(:subscriber_id => user.id.to_s)
        subscribed_thread_ids = subscriptions.collect{|s| s.source_id}

        (subscribed_thread_ids.to_set.superset? thread_ids.to_set).should == true

      end

        it "returns only unflagged threads" do
        start_time = Date.today - 100.days
       

        user = User.create(:external_id => 1,:username => "example")

        sleep 1

        end_time = Time.now + 5.seconds

        post "/api/v1/notifications", from: CGI::escape(start_time.to_s), to: CGI::escape(end_time.to_s), user_ids: user.id

        last_response.should be_ok
        payload = JSON.parse last_response.body
        courses = payload[user.id.to_s]
        thread_ids = []
        courses.each do |k,v|
            v.each do |kk,vv|
                thread_ids << kk
            end
        end
        #now flag the first thread
        thread = CommentThread.find thread_ids.first
        thread.historical_abuse_flaggers << ["1"]

        sleep 1
        
        end_time = Time.now + 5.seconds
        
        post "/api/v1/notifications", from: CGI::escape(start_time.to_s), to: CGI::escape(end_time.to_s), user_ids: user.id
        last_response.should be_ok
        payload = JSON.parse last_response.body
        courses = payload[user.id.to_s]
        new_thread_ids = []
        courses.each do |k,v|
            v.each do |kk,vv|
                new_thread_ids << kk
            end
        end

        (new_thread_ids.include? thread.id).should == false

      end

    end
  end
end
