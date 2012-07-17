require 'spec_helper'

# TODO all api covered
# TODO spec for error handling
# TODO check response for non-retrieval api calls

def parse(text)
  Yajl::Parser.parse text
end

def init_without_subscriptions
  Comment.delete_all
  CommentThread.delete_all
  Commentable.delete_all
  User.delete_all
  Notification.delete_all
  Subscription.delete_all
  
  commentable = Commentable.new(commentable_type: "questions", commentable_id: "1")
  commentable.save!

  user = User.create!(external_id: "1")

  thread = commentable.comment_threads.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1")
  thread.author = user
  thread.save!

  comment = thread.comments.new(body: "this problem is so easy", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "not for me!", course_id: "1")
  comment1.author = user
  comment1.save!
  comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
  comment2.author = user
  comment2.save!

  comment = thread.comments.new(body: "see the textbook on page 69. it's quite similar", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "thank you!", course_id: "1")
  comment1.author = user
  comment1.save!

  thread = commentable.comment_threads.new(title: "This problem is wrong", body: "it is unsolvable", course_id: "2")
  thread.author = user
  thread.save!

  comment = thread.comments.new(body: "how do you know?", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "because blablabla", course_id: "1")
  comment1.author = user
  comment1.save!
  comment = thread.comments.new(body: "no wonder I can't solve it", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "+1", course_id: "1")
  comment1.author = user
  comment1.save!

  users = (2..10).map{|id| User.find_or_create_by(external_id: id.to_s)}

  Comment.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users.each {|user| user.vote(c, [:up, :down].sample)}
  end

  CommentThread.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users.each {|user| user.vote(c, [:up, :down].sample)}
  end

end

def init_with_subscriptions
  Comment.delete_all
  CommentThread.delete_all
  Commentable.delete_all
  User.delete_all
  Notification.delete_all
  Subscription.delete_all

  user1 = User.create!(external_id: "1")
  user2 = User.create!(external_id: "2")

  user2.subscribe(user1)

  commentable = Commentable.new(commentable_type: "questions", commentable_id: "1")
  user1.subscribe(commentable)
  user2.subscribe(commentable)
  commentable.save!

  thread = commentable.comment_threads.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1")
  thread.author = user1
  user2.subscribe(thread)
  thread.save!

  comment = thread.comments.new(body: "this problem is so easy", course_id: "1")
  comment.author = user2
  comment.save!
  comment1 = comment.children.new(body: "not for me!", course_id: "1")
  comment1.author = user1
  comment1.save!
  comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
  comment2.author = user2
  comment2.save!

  thread = commentable.comment_threads.new(title: "This problem is wrong", body: "it is unsolvable", course_id: "2")
  thread.author = user2
  thread.save!

end

describe "app" do
  describe "commentables" do
    before(:each) { init_without_subscriptions }
    describe "DELETE /api/v1/:commentable_type/:commentable_id/threads" do
      it "delete the commentable object and all of its associated comment threads and comments" do
        delete '/api/v1/questions/1/threads'
        last_response.should be_ok
        Commentable.count.should == 0
      end
    end
    describe "GET /api/v1/:commentable_type/:commentable_id/threads" do
      it "get all comment threads associated with a commentable object" do
        get "/api/v1/questions/1/threads"
        last_response.should be_ok
        threads = Yajl::Parser.parse last_response.body
        threads.length.should == 2
        threads.index{|c| c["body"] == "can anyone help me?"}.should_not be_nil
        threads.index{|c| c["body"] == "it is unsolvable"}.should_not be_nil
      end
      it "get all comment threads and comments associated with a commentable object" do
        get "/api/v1/questions/1/threads", recursive: true
        last_response.should be_ok
        threads = Yajl::Parser.parse last_response.body
        threads.length.should == 2
        threads.index{|c| c["body"] == "can anyone help me?"}.should_not be_nil
        threads.index{|c| c["body"] == "it is unsolvable"}.should_not be_nil
        thread = threads.select{|c| c["body"] == "can anyone help me?"}.first
        children = thread["children"]
        children.length.should == 2
        children.index{|c| c["body"] == "this problem is so easy"}.should_not be_nil
        children.index{|c| c["body"] =~ /^see the textbook/}.should_not be_nil
        so_easy = children.select{|c| c["body"] == "this problem is so easy"}.first
        so_easy["children"].length.should == 1
        not_for_me = so_easy["children"].first
        not_for_me["body"].should == "not for me!"
        not_for_me["children"].length.should == 1
        not_for_me["children"].first["body"].should == "not for me neither!"
      end
    end
    describe "POST /api/v1/:commentable_type/:commentable_id/threads" do
      it "create a new comment thread for the commentable object" do
        post '/api/v1/questions/1/threads', title: "Interesting question", body: "cool", course_id: "1", user_id: "1"
        last_response.should be_ok
        CommentThread.count.should == 3
        CommentThread.where(title: "Interesting question").first.should_not be_nil
      end
    end
  end
  describe "comment threads" do
    before(:each) { init_without_subscriptions }
    describe "GET /api/v1/threads/:thread_id" do
      it "get information of a single comment thread" do
        thread = CommentThread.first
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        thread.title.should == response_thread["title"]
        thread.body.should == response_thread["body"]
        thread.course_id.should == response_thread["course_id"]
        thread.votes_point.should == response_thread["votes"]["point"]
        response_thread["children"].should be_nil
      end
      it "get information of a single comment thread with its comments" do
        thread = CommentThread.first
        get "/api/v1/threads/#{thread.id}", recursive: true
        last_response.should be_ok
        response_thread = parse last_response.body
        thread.title.should == response_thread["title"]
        thread.body.should == response_thread["body"]
        thread.course_id.should == response_thread["course_id"]
        thread.votes_point.should == response_thread["votes"]["point"]
        response_thread["children"].should_not be_nil
        response_thread["children"].length.should == thread.comments.length
        response_thread["children"].index{|c| c["body"] == thread.comments.first.body}.should_not be_nil
      end
    end
    describe "PUT /api/v1/threads/:thread_id" do
      it "update information of comment thread" do
        thread = CommentThread.first
        put "/api/v1/threads/#{thread.id}", body: "new body", title: "new title"
        last_response.should be_ok
        changed_thread = CommentThread.find(thread.id)
        changed_thread.body.should == "new body"
        changed_thread.title.should == "new title"
      end
    end
    describe "POST /api/v1/threads/:thread_id/comments" do
      it "create a comment to the comment thread" do
        thread = CommentThread.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/threads/#{thread["_id"]}/comments", body: "new comment", course_id: "1", user_id: User.first.id
        last_response.should be_ok
        changed_thread = CommentThread.find(thread["_id"]).to_hash(recursive: true)
        changed_thread["children"].length.should == thread["children"].length + 1
        comment = changed_thread["children"].select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment["user_id"].should == user.id
      end
    end
    describe "DELETE /api/v1/threads/:thread_id" do
      it "delete the comment thread and its comments" do
        thread = CommentThread.first.to_hash
        delete "/api/v1/threads/#{thread['_id']}"
        last_response.should be_ok
        CommentThread.where(title: thread["title"]).first.should be_nil
      end
    end
  end

  describe "comments" do
    before(:each) { init_without_subscriptions }
    describe "GET /api/v1/comments/:comment_id" do
      it "retrieve information of a single comment" do
        comment = Comment.first
        get "/api/v1/comments/#{comment.id}"
        last_response.should be_ok
        retrieved = parse last_response.body
        retrieved["body"].should == comment.body
        retrieved["endorsed"].should == comment.endorsed
        retrieved["_id"].should == comment.id.to_s
        retrieved["children"].should be_nil
        retrieved["votes"]["point"].should == comment.votes_point
      end
      it "retrieve information of a single comment with its sub comments" do
        comment = Comment.first
        get "/api/v1/comments/#{comment.id}", recursive: true
        last_response.should be_ok
        retrieved = parse last_response.body
        retrieved["body"].should == comment.body
        retrieved["endorsed"].should == comment.endorsed
        retrieved["_id"].should == comment.id.to_s
        retrieved["votes"]["point"].should == comment.votes_point
        retrieved["children"].length.should == comment.children.length
        retrieved["children"].select{|c| c["body"] == comment.children.first.body}.first.should_not be_nil
      end
    end
    describe "PUT /api/v1/comments/:comment_id" do
      it "update information of the comment" do
        comment = Comment.first
        put "/api/v1/comments/#{comment.id}", body: "new body", endorsed: true
        last_response.should be_ok
        new_comment = Comment.find(comment.id)
        new_comment.body.should == "new body"
        new_comment.endorsed.should == true
      end
    end
    describe "POST /api/v1/comments/:comment_id" do
      it "create a sub comment to the comment" do
        comment = Comment.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/comments/#{comment["_id"]}", body: "new comment", course_id: "1", user_id: User.first.id
        last_response.should be_ok
        changed_comment = Comment.find(comment["_id"]).to_hash(recursive: true)
        changed_comment["children"].length.should == comment["children"].length + 1
        subcomment = changed_comment["children"].select{|c| c["body"] == "new comment"}.first
        subcomment.should_not be_nil
        subcomment["user_id"].should == user.id
      end
    end
    describe "DELETE /api/v1/comments/:comment_id" do
      it "delete the comment and its sub comments" do
        comment = Comment.first
        cnt_comments = comment.descendants_and_self.length
        prev_count = Comment.count
        delete "/api/v1/comments/#{comment.id}"
        Comment.count.should == prev_count - cnt_comments
        Comment.all.select{|c| c.id == comment.id}.first.should be_nil
      end
    end
  end
  describe "votes" do
    before(:each) { init_without_subscriptions }
    describe "PUT /api/v1/comments/:comment_id/votes" do
      it "create or update the vote on the comment" do
        user = User.first
        comment = Comment.first
        prev_up_votes = comment.up_votes_count
        prev_down_votes = comment.down_votes_count
        put "/api/v1/comments/#{comment.id}/votes", user_id: user.id, value: "down"
        comment = Comment.find(comment.id)
        comment.up_votes_count.should == prev_up_votes - 1
        comment.down_votes_count.should == prev_down_votes + 1
      end
    end
    describe "DELETE /api/v1/comments/:comment_id/votes" do
      it "unvote on the comment" do
        user = User.first
        comment = Comment.first
        prev_up_votes = comment.up_votes_count
        prev_down_votes = comment.down_votes_count
        delete "/api/v1/comments/#{comment.id}/votes", user_id: user.id
        comment = Comment.find(comment.id)
        comment.up_votes_count.should == prev_up_votes - 1
        comment.down_votes_count.should == prev_down_votes
      end
    end
    describe "PUT /api/v1/threads/:thread_id/votes" do
      it "create or update the vote on the thread" do
        user = User.first
        thread = CommentThread.first
        prev_up_votes = thread.up_votes_count
        prev_down_votes = thread.down_votes_count
        put "/api/v1/threads/#{thread.id}/votes", user_id: user.id, value: "down"
        thread = CommentThread.find(thread.id)
        thread.up_votes_count.should == prev_up_votes - 1
        thread.down_votes_count.should == prev_down_votes + 1
      end
    end
    describe "DELETE /api/v1/threads/:thread_id/votes" do
      it "unvote on the thread" do
        user = User.first
        thread = CommentThread.first
        prev_up_votes = thread.up_votes_count
        prev_down_votes = thread.down_votes_count
        delete "/api/v1/threads/#{thread.id}/votes", user_id: user.id
        thread = CommentThread.find(thread.id)
        thread.up_votes_count.should == prev_up_votes - 1
        thread.down_votes_count.should == prev_down_votes
      end
    end
  end
  describe "subscriptions and notifications" do
    before(:each) { init_with_subscriptions }
    describe "GET /api/v1/users/:user_id/notifications" do
      it "get all notifications on the subscribed comment threads for the user" do
        user = User.find("1")
        get "/api/v1/users/#{user.external_id}/notifications"
        last_response.should be_ok
        notifications = parse last_response.body
        so_easy = Comment.all.select{|c| c.body == "this problem is so easy"}.first
        not_for_me_neither = Comment.all.select{|c| c.body == "not for me neither!"}.first
        notification_so_easy = notifications.select{|f| f["notification_type"] == "post_reply" and f["info"]["comment_id"] == so_easy.id.to_s}.first
        notification_so_easy.should_not be_nil
        notification_not_for_me_neither = notifications.select{|f| f["notification_type"] == "post_reply" and f["info"]["comment_id"] == not_for_me_neither.id.to_s}.first
        notification_not_for_me_neither.should_not be_nil
      end
      it "get all notifications on the subscribed commentable for the user" do
        user = User.find("1")
        get "/api/v1/users/#{user.external_id}/notifications"
        last_response.should be_ok
        notifications = parse last_response.body
        notifications.select{|f| f["notification_type"] == "post_topic"}.length.should == 1
        problem_wrong = notifications.select{|f| f["notification_type"] == "post_topic"}.first
        problem_wrong["info"]["thread_title"].should == "This problem is wrong"
      end
    end
    describe "POST /api/v1/users/:user_id/subscriptions" do
      it "follow user" do
        user1 = User.find("1")
        user2 = User.find("2")
        post "/api/v1/users/#{user1.external_id}/subscriptions", subscribed_type: "user", subscribed_id: user2.external_id
        last_response.should be_ok
        User.find("2").followers.length.should == 1
        User.find("2").followers.should include user1
      end
      it "unfollow user" do
        user1 = User.find("1")
        user2 = User.find("2")
        delete "/api/v1/users/#{user2.external_id}/subscriptions", subscribed_type: "user", subscribed_id: user1.external_id
        last_response.should be_ok
        User.find("1").followers.length.should == 0
      end
      it "subscribe a commentable" do
        user3 = User.find_or_create_by(external_id: "3")
        post "/api/v1/users/#{user3.external_id}/subscriptions", subscribed_type: "questions", subscribed_id: "1"
        last_response.should be_ok
        Commentable.first.subscribers.length.should == 3
        Commentable.first.subscribers.should include user3
      end
      it "unsubscribe a commentable" do
        user2 = User.find_or_create_by(external_id: "2")
        delete "/api/v1/users/#{user2.external_id}/subscriptions", subscribed_type: "questions", subscribed_id: "1"
        last_response.should be_ok
        Commentable.first.subscribers.length.should == 1
        Commentable.first.subscribers.should_not include user2
      end
      it "subscribe a comment thread" do
        user1 = User.find_or_create_by(external_id: "1")
        thread = CommentThread.where(body: "it is unsolvable").first
        post "/api/v1/users/#{user1.external_id}/subscriptions", subscribed_type: "thread", subscribed_id: thread.id
        last_response.should be_ok
        thread = CommentThread.where(body: "it is unsolvable").first
        thread.subscribers.length.should == 2
        thread.subscribers.should include user1
      end
      it "unsubscribe a comment thread" do
        user2 = User.find_or_create_by(external_id: "2")
        thread = CommentThread.where(body: "it is unsolvable").first
        delete "/api/v1/users/#{user2.external_id}/subscriptions", subscribed_type: "thread", subscribed_id: thread.id
        last_response.should be_ok
        thread = CommentThread.where(body: "it is unsolvable").first
        thread.subscribers.length.should == 0
      end
    end
  end
end
