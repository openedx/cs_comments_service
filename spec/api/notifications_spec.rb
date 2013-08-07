require 'spec_helper'

describe "app" do
  describe "notifications" do
    before(:each) { init_without_subscriptions }
    describe "POST /api/v1/notifications" do
      it "returns notifications by class and user" do
        start_time = Time.now
        user = User.create(:email => "test@example.com",:external_id => 1,:username => "example")
        commentable = Commentable.new("question_1")
        random_string = (0...8).map{ ('a'..'z').to_a[rand(26)] }.join
        thread = CommentThread.new(title: "Test title", body: "elephant otter", course_id: "1", commentable_id: commentable.id, comments_text_dummy: random_string)
        thread.author = user
        thread.save!

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

        # first make a dummy thread and comment and a subscription
        commentable = Commentable.new("question_1")
        user = User.create(:email => "test@example.com",:external_id => 1,:username => "example")
        random_string = (0...8).map{ ('a'..'z').to_a[rand(26)] }.join

        thread = CommentThread.new(title: "Test title", body: "elephant otter", course_id: "1", commentable_id: commentable.id, comments_text_dummy: random_string)
        thread.author = user
        thread.save!

        subscription = Subscription.create({:subscriber_id => user._id.to_s, :source_id => thread._id.to_s})

        comment = Comment.new(body: random_string, course_id: "1", commentable_id: commentable.id)
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
       

        user = User.create(:email => "test@example.com",:external_id => 1,:username => "example")

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
