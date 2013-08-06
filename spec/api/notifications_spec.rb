require 'spec_helper'

describe "app" do
  describe "notifications" do
    before(:each) { init_without_subscriptions }
    describe "POST /api/v1/notifications" do
      it "returns notifications by class and user" do
        start_time = Time.now
        user = User.first
        thread = CommentThread.first
        subscription = Subscription.create({:subscriber_id => user._id.to_s, :source_id => thread._id.to_s})

        dummy = random_string = (0..5).map{ ('a'..'z').to_a[rand(26)] }.join
        comment = Comment.new
        comment.comment_thread_id = thread.id
        comment.body = dummy
        comment.author_id = user.id
        comment.course_id = 'test course'
        comment.save!

        sleep 1

        end_time = Time.now

        post "/api/v1/notifications", from: CGI::escape(start_time.to_s), to: CGI::escape(end_time.to_s), user_ids: subscription.subscriber_id
        last_response.should be_ok
        last_response.body.to_s.include?(dummy).should == true
      end

      it "returns only threads subscribed to by user" do
        start_time = Date.today - 400.days
        end_time = Time.now
        user = User.find Subscription.first.subscriber_id
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
        puts user.id
        subscriptions = Subscription.where(:subscriber_id => user.id.to_s)
        subscribed_thread_ids = subscriptions.collect{|s| s.source_id}

        (subscribed_thread_ids.to_set.superset? thread_ids.to_set).should == true

      end

    end
  end
end
