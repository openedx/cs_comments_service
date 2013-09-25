require 'spec_helper'

describe "app" do
  describe "comment threads" do

    describe "GET /api/v1/threads" do

      before(:each) do
        
        User.all.delete
        Content.all.delete

        @threads = {}
        @comments = {}
        10.times do |i|
          author = create_test_user(i+100)
          thread = make_thread(author, "t#{i}", "xyz", "pdq")
          @threads["t#{i}"] = thread
          5.times do |j|
            comment = make_comment(author, thread, "t#{i} c#{j}")
            @comments["t#{i} c#{j}"] = comment
          end
        end
        @natural_order = 10.times.map {|i| "t#{i}"}
      end

      def thread_result(params)
        get "/api/v1/threads", params
        last_response.should be_ok
        parse(last_response.body)["collection"]
      end

      context "when filtering by course" do
        it "returns only threads with matching course id" do
          [@threads["t1"], @threads["t2"]].each do |t| 
            t.course_id = "abc"
            t.save! 
          end 
          rs = thread_result course_id: "abc"
          rs.length.should == 2 
          rs.each_with_index { |res, i|
            check_thread_result(nil, @threads["t#{i+1}"], res)
            res["course_id"].should == "abc"
          }
        end
        it "returns only threads where course id and group id match" do
          @threads["t1"].course_id = "omg"
          @threads["t1"].group_id = 100
          @threads["t1"].save!
          @threads["t2"].course_id = "omg"
          @threads["t2"].group_id = 101
          @threads["t2"].save!
          rs = thread_result course_id: "omg", group_id: 100
          rs.length.should == 1
          check_thread_result(nil, @threads["t1"], rs.first)
        end
        it "returns only threads where course id and group id match or group id is nil" do
          @threads["t1"].course_id = "omg"
          @threads["t1"].group_id = 100
          @threads["t1"].save!
          @threads["t2"].course_id = "omg"
          @threads["t2"].group_id = nil
          @threads["t2"].save!
          @threads["t3"].group_id = 100
          @threads["t3"].save!
          rs = thread_result course_id: "omg", group_id: 100
          rs.length.should == 2 
          rs.each_with_index { |res, i|
            check_thread_result(nil, @threads["t#{i+1}"], res)
            res["course_id"].should == "omg"
          }
        end
        it "returns an empty result when no threads match course_id" do
          rs = thread_result course_id: 99
          rs.length.should == 0 
        end
        context "when filtering flagged posts" do
          it "returns threads that are flagged" do
            @threads["t1"].abuse_flaggers = [1]
            @threads["t1"].save!
            rs = thread_result course_id: "xyz", flagged: true
            rs.length.should == 1 
            check_thread_result(nil, @threads["t1"], rs.first)
          end
          it "returns threads that have flagged comments" do
            @comments["t2 c3"].abuse_flaggers = [1]            
            @comments["t2 c3"].save!
            rs = thread_result course_id: "xyz", flagged: true
            rs.length.should == 1 
            check_thread_result(nil, @threads["t2"], rs.first)
          end
          it "returns an empty result when no posts were flagged" do
            rs = thread_result course_id: "xyz", flagged: true
            rs.length.should == 0 
          end
        end
        it "correctly considers read state" do
          user = create_test_user(123)
          [@threads["t1"], @threads["t2"]].each do |t| 
            t.course_id = "abc"
            t.save! 
          end 
          rs = thread_result course_id: "abc", user_id: "123"
          rs.length.should == 2 
          rs.each_with_index { |result, i|
            check_thread_result(user, @threads["t#{i+1}"], result)
            result["course_id"].should == "abc"
            result["unread_comments_count"].should == 5
            result["read"].should == false
          }

          user.mark_as_read(@threads["t1"])
          rs = thread_result course_id: "abc", user_id: "123"
          rs.length.should == 2
          rs.each_with_index { |result, i|
            check_thread_result(user, @threads["t#{i+1}"], result)
          }
          rs[0]["unread_comments_count"].should == 0
          rs[0]["read"].should == true
          rs[1]["unread_comments_count"].should == 5
          rs[1]["read"].should == false
        end

        context "sorting" do
          def thread_result_order (sort_key, sort_order)
            get "/api/v1/threads", course_id: "xyz", sort_key: sort_key, sort_order: sort_order
            last_response.should be_ok
            results = parse(last_response.body)["collection"]
            results.length.should == 10 
            results.map {|t| t["title"]}
          end

          def move_to_end(ary, val)
            ary.select {|v| v!=val } << val
          end

          def move_to_front(ary, val)
            ary.select {|v| v!=val }.insert(0, val)
          end

          it "sorts using create date / ascending" do
            actual_order = thread_result_order("date", "asc")
            expected_order = @natural_order
            actual_order.should == expected_order
          end
          it "sorts using create date / descending" do
            actual_order = thread_result_order("date", "desc")
            expected_order = @natural_order.reverse
            actual_order.should == expected_order
          end
          it "sorts using last activity / ascending" do
            t5c = @threads["t5"].comments.first
            t5c.update(body: "changed!")
            t5c.save!
            actual_order = thread_result_order("activity", "asc")
            expected_order = move_to_end(@natural_order, "t5") 
            actual_order.should == expected_order
          end
          it "sorts using vote count" do
            user = User.all.first
            t5c = @threads["t5"].comments.first
            user.vote(t5c, :up)
            t5c.save!
            actual_order = thread_result_order("activity", "asc")
            expected_order = move_to_end(@natural_order, "t5") 
            actual_order.should == expected_order
          end
          it "sorts using comment count" do
            make_comment(@threads["t5"].author, @threads["t5"], "extra comment")
            actual_order = thread_result_order("comments", "asc")
            expected_order = move_to_end(@natural_order, "t5") 
            actual_order.should == expected_order
          end
          it "sorts pinned items first" do
            make_comment(@threads["t5"].author, @threads["t5"], "extra comment")
            @threads["t7"].pinned = true
            @threads["t7"].save!
            actual_order = thread_result_order("comments", "asc")
            expected_order = move_to_front(move_to_end(@natural_order, "t5"), "t7")
            actual_order.should == expected_order
          end
          
          context "pagination" do
            def thread_result_page (sort_key, sort_order, page, per_page)
              get "/api/v1/threads", course_id: "xyz", sort_key: sort_key, sort_order: sort_order, page: page, per_page: per_page
              last_response.should be_ok
              parse(last_response.body)
            end

            it "returns single page" do
              result = thread_result_page("date", "desc", 1, 20)
              result["collection"].length.should == 10
              result["num_pages"].should == 1
              result["page"].should == 1
            end
            it "returns multiple pages" do
              result = thread_result_page("date", "desc", 1, 5)
              result["collection"].length.should == 5
              result["num_pages"].should == 2
              result["page"].should == 1

              result = thread_result_page("date", "desc", 2, 5)
              result["collection"].length.should == 5
              result["num_pages"].should == 2
              result["page"].should == 2
            end
            it "orders correctly across pages" do
              make_comment(@threads["t5"].author, @threads["t5"], "extra comment")
              @threads["t7"].pinned = true
              @threads["t7"].save!
              expected_order = move_to_front(move_to_end(@natural_order, "t5"), "t7")
              actual_order = []
              pp = 3 # per page
              4.times do |i|
                n = i + 1
                result = thread_result_page("comments", "asc", n, pp)
                result["collection"].length.should == [n * pp, 10].min - ((n - 1) * pp)
                result["num_pages"].should == 4
                result["page"].should == n
                actual_order += result["collection"].map {|v| v["title"]}
              end
              actual_order.should == expected_order
            end
          end
        end
        
      end

    end

    describe "GET /api/v1/threads/:thread_id" do

      before(:each) { init_without_subscriptions }
      
      it "get information of a single comment thread" do
        thread = CommentThread.first
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        check_thread_result(nil, thread, response_thread)
      end

      it "computes endorsed? correctly" do
        thread = CommentThread.first
        comment = thread.root_comments[1]
        comment.endorsed = true
        comment.save!
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        response_thread["endorsed"].should == true
        check_thread_result(nil, thread, response_thread)
      end

      # This is a test to ensure that the username is included even if the
      # thread's author is the one looking at the comment. This is because of a
      # regression in which we used User.only(:id, :read_states). This worked
      # before we included the identity map, but afterwards, the user was
      # missing the username and was not refetched.
      it "includes the username even if the thread is being marked as read for the thread author" do
        thread = CommentThread.first
        expected_username = thread.author.username

        # We need to clear the IdentityMap after getting the expected data to
        # ensure that this spec fails when it should. If we don't do this, then
        # in the cases where the User is fetched without its username, the spec
        # won't fail because the User will already be in the identity map. 
        Mongoid::IdentityMap.clear

        get "/api/v1/threads/#{thread.id}", {:user_id => thread.author_id, :mark_as_read => true}
        last_response.should be_ok
        response_thread = parse last_response.body
        response_thread["username"].should == expected_username
      end

      it "get information of a single comment thread with its comments" do
        thread = CommentThread.first
        get "/api/v1/threads/#{thread.id}", recursive: true
        last_response.should be_ok
        check_thread_result(nil, thread, parse(last_response.body), true)
      end

      it "returns 400 when the thread does not exist" do
        get "/api/v1/threads/does_not_exist"
        last_response.status.should == 400
        get "/api/v1/threads/5016a3caec5eb9a12300000b1"
        last_response.status.should == 400
      end
      
      it "get information of a single comment thread with its tags" do
        thread = CommentThread.new
        thread.title = "new thread"
        thread.body = "hahaah"
        thread.course_id = "1"
        thread.commentable_id = "1"
        thread.author = User.first
        thread.tags = "taga, tagb, tagc"
        thread.save!
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        check_thread_result(nil, thread, response_thread)
        response_thread["tags"].length.should == 3
        response_thread["tags"].should include "taga"
        response_thread["tags"].should include "tagb"
        response_thread["tags"].should include "tagc"
      end
    end
    describe "PUT /api/v1/threads/:thread_id" do

      before(:each) { init_without_subscriptions }
      
      it "update information of comment thread" do
        thread = CommentThread.first
        put "/api/v1/threads/#{thread.id}", body: "new body", title: "new title", commentable_id: "new_commentable_id"
        last_response.should be_ok
        changed_thread = CommentThread.find(thread.id)
        changed_thread.body.should == "new body"
        changed_thread.title.should == "new title"
        changed_thread.commentable_id.should == "new_commentable_id"
        check_thread_result(nil, changed_thread, parse(last_response.body))
      end
      it "returns 400 when the thread does not exist" do
        put "/api/v1/threads/does_not_exist", body: "new body", title: "new title"
        last_response.status.should == 400
      end
      it "returns 503 if the post body has been blocked" do
        thread = CommentThread.first
        put "/api/v1/threads/#{thread.id}", body: "BLOCKED POST", title: "new title", commentable_id: "new_commentable_id"
        last_response.status.should == 503
        put "/api/v1/threads/#{thread.id}", body: "blocked,   post...", title: "new title", commentable_id: "new_commentable_id"
        last_response.status.should == 503
      end
      it "updates tag of comment thread" do
        thread = CommentThread.first
        put "/api/v1/threads/#{thread.id}", tags: "haha, hoho, huhu"
        last_response.should be_ok
        thread.reload
        thread.tags_array.length.should == 3
        thread.tags_array.should include "haha"
        thread.tags_array.should include "hoho"
        thread.tags_array.should include "huhu"
        put "/api/v1/threads/#{thread.id}", tags: "aha, oho"
        last_response.should be_ok
        thread.reload
        thread.tags_array.length.should == 2
        thread.tags_array.should include "aha"
        thread.tags_array.should include "oho"
      end
    end
    describe "POST /api/v1/threads/:thread_id/comments" do

      before(:each) { init_without_subscriptions }

      let :default_params  do
        {body: "new comment", course_id: "1", user_id: User.first.id}
      end
      it "create a comment to the comment thread" do
        thread = CommentThread.first.to_hash(recursive: true)
        user = User.first
        post "/api/v1/threads/#{thread["id"]}/comments", default_params
        last_response.should be_ok
        changed_thread = CommentThread.find(thread["id"]).to_hash(recursive: true)
        changed_thread["children"].length.should == thread["children"].length + 1
        comment = changed_thread["children"].select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment["user_id"].should == user.id
      end
      it "allows anonymous comment" do
        thread = CommentThread.first.to_hash(recursive: true)
        post "/api/v1/threads/#{thread["id"]}/comments", default_params.merge(anonymous: true)
        last_response.should be_ok
        changed_thread = CommentThread.find(thread["id"]).to_hash(recursive: true)
        changed_thread["children"].length.should == thread["children"].length + 1
        comment = changed_thread["children"].select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment["anonymous"].should be_true
      end
      it "returns 400 when the thread does not exist" do
        post "/api/v1/threads/does_not_exist/comments", default_params
        last_response.status.should == 400
      end
      it "returns error when body or course_id does not exist, or when body is blank" do
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(body: nil)
        last_response.status.should == 400
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(course_id: nil)
        last_response.status.should == 400
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(body: "    \n      \n  ")
        last_response.status.should == 400
      end
      it "returns 503 when the post body has been blocked" do
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(body: "BLOCKED POST")
        last_response.status.should == 503
      end
    end
    describe "DELETE /api/v1/threads/:thread_id" do
      it "delete the comment thread and its comments" do
        thread = CommentThread.first.to_hash
        delete "/api/v1/threads/#{thread['id']}"
        last_response.should be_ok
        CommentThread.where(title: thread["title"]).first.should be_nil
      end
      it "returns 400 when the thread does not exist" do
        delete "/api/v1/threads/does_not_exist"
        last_response.status.should == 400
      end
    end
  end
  describe "GET /api/v1/threads/tags" do
    it "get all tags used in threads" do
      CommentThread.recalculate_all_context_tag_weights!
      thread1 = CommentThread.all.to_a.first
      thread2 = CommentThread.all.to_a.last
      thread1.tags = "a, b, c"
      thread1.save
      thread2.tags = "d, e, f"
      thread2.save
      get "/api/v1/threads/tags"
      last_response.should be_ok
      tags = parse last_response.body
      tags.length.should == 6
    end
  end
  describe "GET /api/v1/threads/tags/autocomplete" do
    def create_comment_thread(tags)
      c = CommentThread.new(title: "Interesting question", body: "cool")
      c.course_id = "1"
      c.author = User.first
      c.tags = tags
      c.commentable_id = "1"
      c.save!
      c
    end
    it "returns autocomplete results" do
      CommentThread.delete_all
      CommentThread.recalculate_all_context_tag_weights!
      create_comment_thread "c++, clojure, common-lisp, c#, c, coffeescript"
      create_comment_thread "c++, clojure, common-lisp, c#, c"
      create_comment_thread "c++, clojure, common-lisp, c#"
      create_comment_thread "c++, clojure, common-lisp"
      create_comment_thread "c++, clojure"
      create_comment_thread "c++"
      get "/api/v1/threads/tags/autocomplete", value: "c"
      last_response.should be_ok
      results = parse last_response.body
      results.length.should == 5
      %w[c++ clojure common-lisp c# c].each_with_index do |tag, index|
        results[index].should == tag
      end
    end
  end
end
