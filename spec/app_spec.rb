require 'spec_helper'

# TODO all api covered
# TODO spec for error handling
# TODO check response for non-retrieval api calls

def parse(text)
  Yajl::Parser.parse text
end

def init_without_feeds
  Comment.delete_all
  CommentThread.delete_all
  Commentable.delete_all
  User.delete_all
  Feed.delete_all
  
  commentable = Commentable.new(commentable_type: "questions", commentable_id: "1")
  commentable.save!

  user = User.create!(id: "1")

  comment_thread = commentable.comment_threads.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1")
  comment_thread.author = user
  comment_thread.save!

  comment = comment_thread.comments.new(body: "this problem is so easy", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "not for me!", course_id: "1")
  comment1.author = user
  comment1.save!
  comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
  comment2.author = user
  comment2.save!

  comment = comment_thread.comments.new(body: "see the textbook on page 69. it's quite similar", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "thank you!", course_id: "1")
  comment1.author = user
  comment1.save!

  comment_thread = commentable.comment_threads.new(title: "This problem is wrong", body: "it is unsolvable", course_id: "2")
  comment_thread.author = user
  comment_thread.save!

  comment = comment_thread.comments.new(body: "how do you know?", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "because blablabla", course_id: "1")
  comment1.author = user
  comment1.save!
  comment = comment_thread.comments.new(body: "no wonder I can't solve it", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "+1", course_id: "1")
  comment1.author = user
  comment1.save!

  users = (2..10).map{|id| User.find_or_create_by(id: id.to_s)}

  Comment.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users.each {|user| user.vote(c, [:up, :down].sample)}
  end

  CommentThread.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users.each {|user| user.vote(c, [:up, :down].sample)}
  end
end

describe "app" do
  describe "commentables" do
    before(:each) { init_without_feeds }
    describe "DELETE /api/v1/commentables/:commentable_type/:commentable_id" do
      it "delete the commentable object and all of its associated comment threads and comments" do
        delete '/api/v1/commentables/questions/1'
        last_response.should be_ok
        Commentable.count.should == 0
      end
    end
    describe "GET /api/v1/commentables/:commentable_type/:commentable_id/comment_threads" do
      it "get all comment threads associated with a commentable object" do
        get "/api/v1/commentables/questions/1/comment_threads"
        last_response.should be_ok
        comment_threads = Yajl::Parser.parse last_response.body
        comment_threads.length.should == 2
        comment_threads.index{|c| c["body"] == "can anyone help me?"}.should_not be_nil
        comment_threads.index{|c| c["body"] == "it is unsolvable"}.should_not be_nil
      end
      it "get all comment threads and comments associated with a commentable object" do
        get "/api/v1/commentables/questions/1/comment_threads", recursive: true
        last_response.should be_ok
        comment_threads = Yajl::Parser.parse last_response.body
        comment_threads.length.should == 2
        comment_threads.index{|c| c["body"] == "can anyone help me?"}.should_not be_nil
        comment_threads.index{|c| c["body"] == "it is unsolvable"}.should_not be_nil
        comment_thread = comment_threads.select{|c| c["body"] == "can anyone help me?"}.first
        children = comment_thread["children"]
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
    describe "POST /api/v1/commentables/:commentable_type/:commentable_id/comment_threads" do
      it "create a new comment thread for the commentable object" do
        post '/api/v1/commentables/questions/1/comment_threads', title: "Interesting question", body: "cool", course_id: "1"
        last_response.should be_ok
        CommentThread.count.should == 3
        CommentThread.where(title: "Interesting question").first.should_not be_nil
      end
    end
  end

  describe "comment threads" do
    before(:each) { init_without_feeds }
    describe "GET /api/v1/comment_threads/:comment_thread_id" do
      it "get information of a single comment thread" do
        comment_thread = CommentThread.first
        get "/api/v1/comment_threads/#{comment_thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        comment_thread.title.should == response_thread["title"]
        comment_thread.body.should == response_thread["body"]
        comment_thread.course_id.should == response_thread["course_id"]
        comment_thread.votes_point.should == response_thread["votes"]["point"]
        response_thread["children"].should be_nil
      end
      it "get information of a single comment thread with its comments" do
        comment_thread = CommentThread.first
        get "/api/v1/comment_threads/#{comment_thread.id}", recursive: true
        last_response.should be_ok
        response_thread = parse last_response.body
        comment_thread.title.should == response_thread["title"]
        comment_thread.body.should == response_thread["body"]
        comment_thread.course_id.should == response_thread["course_id"]
        comment_thread.votes_point.should == response_thread["votes"]["point"]
        response_thread["children"].should_not be_nil
        response_thread["children"].length.should == comment_thread.comments.length
        response_thread["children"].index{|c| c["body"] == comment_thread.comments.first.body}.should_not be_nil
      end
    end
    describe "PUT /api/v1/comment_threads/:comment_thread_id" do
      it "update information of comment thread" do
        comment_thread = CommentThread.first
        put "/api/v1/comment_threads/#{comment_thread.id}", body: "new body", title: "new title"
        last_response.should be_ok
        changed_thread = CommentThread.find(comment_thread.id)
        changed_thread.body.should == "new body"
        changed_thread.title.should == "new title"
      end
    end
    # POST /api/v1/comment_threads/:comment_thread_id/comments
    describe "POST /api/v1/comment_threads/:comment_thread_id/comments" do
      it "create a comment to the comment thread" do
        comment_thread = CommentThread.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/comment_threads/#{comment_thread["_id"]}/comments", body: "new comment", course_id: "1", user_id: User.first.id
        last_response.should be_ok
        changed_thread = CommentThread.find(comment_thread["_id"]).to_hash(recursive: true)
        changed_thread["children"].length.should == comment_thread["children"].length + 1
        comment = changed_thread["children"].select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment["user_id"].should == user.id
      end
    end
    describe "DELETE /api/v1/comment_threads/:comment_thread_id" do
      it "delete the comment thread and its comments" do
        comment_thread = CommentThread.first.to_hash
        delete "/api/v1/comment_threads/#{comment_thread['_id']}"
        last_response.should be_ok
        CommentThread.where(title: comment_thread["title"]).first.should be_nil
      end
    end
  end

  describe "comments" do
    before(:each) { init_without_feeds }
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
    before(:each) { init_without_feeds }
    describe "PUT /api/v1/votes/comments/:comment_id/users/:user_id" do
      it "create or update the vote on the comment" do
        user = User.first
        comment = Comment.first
        prev_up_votes = comment.up_votes_count
        prev_down_votes = comment.down_votes_count
        put "/api/v1/votes/comments/#{comment.id}/users/#{user.id}", value: "down"
        comment = Comment.find(comment.id)
        comment.up_votes_count.should == prev_up_votes - 1
        comment.down_votes_count.should == prev_down_votes + 1
      end
    end
    describe "DELETE /api/v1/votes/comments/:comment_id/users/:user_id" do
      it "unvote on the comment" do
        user = User.first
        comment = Comment.first
        prev_up_votes = comment.up_votes_count
        prev_down_votes = comment.down_votes_count
        delete "/api/v1/votes/comments/#{comment.id}/users/#{user.id}"
        comment = Comment.find(comment.id)
        comment.up_votes_count.should == prev_up_votes - 1
        comment.down_votes_count.should == prev_down_votes
      end
    end
    describe "PUT /api/v1/votes/comment_threads/:comment_thread_id/users/:user_id" do
      it "create or update the vote on the comment thread" do
        user = User.first
        comment_thread = CommentThread.first
        prev_up_votes = comment_thread.up_votes_count
        prev_down_votes = comment_thread.down_votes_count
        put "/api/v1/votes/comment_threads/#{comment_thread.id}/users/#{user.id}", value: "down"
        comment_thread = CommentThread.find(comment_thread.id)
        comment_thread.up_votes_count.should == prev_up_votes - 1
        comment_thread.down_votes_count.should == prev_down_votes + 1
      end
    end
    describe "DELETE /api/v1/votes/comment_threads/:comment_thread_id/users/:user_id" do
      it "unvote on the comment thread" do
        user = User.first
        comment_thread = CommentThread.first
        prev_up_votes = comment_thread.up_votes_count
        prev_down_votes = comment_thread.down_votes_count
        delete "/api/v1/votes/comment_threads/#{comment_thread.id}/users/#{user.id}"
        comment_thread = CommentThread.find(comment_thread.id)
        comment_thread.up_votes_count.should == prev_up_votes - 1
        comment_thread.down_votes_count.should == prev_down_votes
      end
    end
  end
  describe "feeds" do
    describe "GET /api/v1/users/:user_id/feeds" do
      it "get all subscribed feeds for the user" do

      end
    end
    describe "POST /api/v1/users/:user_id/follow" do
      it "follow user" do

      end
    end
    describe "POST /api/v1/users/:user_id/unfollow" do
      it "unfollow user" do

      end
    end
    describe "POST /api/v1/users/:user_id/watch/commentable" do
      it "watch a commentable" do

      end
    end
    describe "POST /api/v1/users/:user_id/unwatch/commentable" do
      it "unwatch a commentable" do

      end
    end
    describe "POST /api/v1/users/:user_id/watch/comment_thread" do
      it "watch a comment thread" do

      end
    end
    describe "POST /api/v1/users/:user_id/unwatch/comment_thread" do
      it "unwatch a comment thread" do

      end
    end
  end
end
