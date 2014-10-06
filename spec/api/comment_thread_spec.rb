require 'spec_helper'
require 'unicode_shared_examples'

describe "app" do
  describe "comment threads" do

    before(:each) { set_api_key_header }

    describe "GET /api/v1/threads" do

      before(:each) { setup_10_threads }

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
          rs = thread_result course_id: "abc", sort_order: "asc"
          rs.length.should == 2 
          rs.each_with_index { |res, i|
            check_thread_result_json(nil, @threads["t#{i+1}"], res)
            res["course_id"].should == "abc"
          }
        end
        it "returns only threads where course id and commentable id match" do
          @threads["t1"].course_id = "course1"
          @threads["t1"].commentable_id = "commentable1"
          @threads["t1"].save!
          @threads["t2"].course_id = "course1"
          @threads["t2"].commentable_id = "commentable2"
          @threads["t2"].save!
          @threads["t3"].course_id = "course1"
          @threads["t3"].commentable_id = "commentable3"
          @threads["t3"].save!
          @threads["t4"].course_id = "course2"
          @threads["t4"].commentable_id = "commentable1"
          @threads["t4"].save!
          rs = thread_result course_id: "course1", commentable_ids: "commentable1,commentable3"
          rs.length.should == 2
          check_thread_result_json(nil, @threads["t3"], rs[0])
          check_thread_result_json(nil, @threads["t1"], rs[1])
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
          check_thread_result_json(nil, @threads["t1"], rs.first)
        end
        it "returns only threads where course id and group ids match" do
          @threads["t1"].course_id = "omg"
          @threads["t1"].group_id = 100
          @threads["t1"].save!
          @threads["t2"].course_id = "omg"
          @threads["t2"].group_id = 101
          @threads["t2"].save!
          rs = thread_result course_id: "omg", group_ids: "100,101", sort_order: "asc"
          rs.length.should == 2
        end
        it "returns only threads where course id and group id match or group id is nil" do
          @threads["t1"].course_id = "omg"
          @threads["t1"].group_id = 100
          @threads["t1"].save!
          @threads["t2"].course_id = "omg"
          @threads["t2"].save!
          @threads["t3"].group_id = 100
          @threads["t3"].save!
          rs = thread_result course_id: "omg", group_id: 100, sort_order: "asc"
          rs.length.should == 2 
          rs.each_with_index { |res, i|
            check_thread_result_json(nil, @threads["t#{i+1}"], res)
            res["course_id"].should == "omg"
          }
        end
        it "returns an empty result when no threads match course_id" do
          rs = thread_result course_id: 99
          rs.length.should == 0 
        end
        it "returns only group-less threads when no threads have matching group id" do
          @threads["t1"].group_id = 123
          @threads["t1"].save!
          rs = thread_result course_id: DFLT_COURSE_ID, group_id: 321
          rs.each.map {|res| res["group_id"].should be_nil }
        end
        context "when filtering flagged posts" do
          it "returns threads that are flagged" do
            @threads["t1"].abuse_flaggers = [1]
            @threads["t1"].save!
            rs = thread_result course_id: DFLT_COURSE_ID, flagged: true
            rs.length.should == 1 
            check_thread_result_json(nil, @threads["t1"], rs.first)
          end
          it "returns threads that have flagged comments" do
            @comments["t2 c3"].abuse_flaggers = [1]            
            @comments["t2 c3"].save!
            rs = thread_result course_id: DFLT_COURSE_ID, flagged: true
            rs.length.should == 1 
            check_thread_result_json(nil, @threads["t2"], rs.first)
          end
          it "returns an empty result when no posts were flagged" do
            rs = thread_result course_id: DFLT_COURSE_ID, flagged: true
            rs.length.should == 0 
          end
        end
        it "filters unread posts" do
          user = create_test_user(Random.new)
          rs = thread_result course_id: DFLT_COURSE_ID, user_id: user.id
          rs.length.should == 10
          rs2 = thread_result course_id: DFLT_COURSE_ID, user_id: user.id, unread: true
          rs2.should == rs
          user.mark_as_read(@threads[rs.first["title"]])
          rs3 = thread_result course_id: DFLT_COURSE_ID, user_id: user.id, unread: true
          rs3.should == rs[1..9]
          rs[1..8].each { |r| user.mark_as_read(@threads[r["title"]]) }
          rs4 = thread_result course_id: DFLT_COURSE_ID, user_id: user.id, unread: true
          rs4.should == rs[9, 1]
          user.mark_as_read(@threads[rs.last["title"]])
          rs5 = thread_result course_id: DFLT_COURSE_ID, user_id: user.id, unread: true
          rs5.should == []
          make_comment(create_test_user(Random.new), @threads[rs.first["title"]], "new activity")
          rs6 = thread_result course_id: DFLT_COURSE_ID, user_id: user.id, unread: true
          rs6.length.should == 1
          rs6.first["title"].should == rs.first["title"]
        end
        it "filters unanswered questions" do
          %w[t9 t7 t5 t3 t1].each do |thread_key|
            @threads[thread_key].thread_type = :question
            @threads[thread_key].save!
          end
          rs = thread_result course_id: DFLT_COURSE_ID, unanswered: true
          rs.length.should == 5
          @comments["t1 c0"].endorsed = true
          @comments["t1 c0"].save!
          rs2 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
          rs2.length.should == 4
          %w[t9 t7 t5].each do |thread_key|
            comment = @threads[thread_key].comments.first
            comment.endorsed = true
            comment.save!
          end
          rs3 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
          rs3.length.should == 1
          @comments["t3 c0"].endorsed = true
          @comments["t3 c0"].save!
          rs3 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
          rs3.length.should == 0
        end
        it "ignores endorsed comments that are not question responses" do
          thread = @threads["t0"]
          thread.thread_type = :question
          thread.save!
          comment = make_comment(create_test_user(Random.new), thread.comments.first, "comment on a response")
          comment.endorsed = true
          comment.save!
          rs = thread_result course_id: DFLT_COURSE_ID, unanswered: true
          rs.length.should == 1
        end
        it "correctly considers read state" do
          user = create_test_user(123)
          [@threads["t1"], @threads["t2"]].each do |t| 
            t.course_id = "abc"
            t.save! 
          end 
          rs = thread_result course_id: "abc", user_id: "123", sort_order: "asc"
          rs.length.should == 2 
          rs.each_with_index { |result, i|
            check_thread_result_json(user, @threads["t#{i+1}"], result)
            result["course_id"].should == "abc"
            result["unread_comments_count"].should == 5
            result["read"].should == false
          }

          user.mark_as_read(@threads["t1"])
          rs = thread_result course_id: "abc", user_id: "123", sort_order: "asc"
          rs.length.should == 2
          rs.each_with_index { |result, i|
            check_thread_result_json(user, @threads["t#{i+1}"], result)
          }
          rs[0]["read"].should == true
          rs[0]["unread_comments_count"].should == 0
          rs[1]["read"].should == false
          rs[1]["unread_comments_count"].should == 5

          @threads["t1"].updated_at += 1 # 1 second later
          @threads["t1"].save!
          rs = thread_result course_id: "abc", user_id: "123", sort_order: "asc"
          rs.length.should == 2
          rs.each_with_index { |result, i|
            check_thread_result_json(user, @threads["t#{i+1}"], result)
          }
          rs[0]["read"].should == false # no unread comments, but the thread itself was updated
          rs[0]["unread_comments_count"].should == 0
          rs[1]["read"].should == false
          rs[1]["unread_comments_count"].should == 5

          # author's own posts should not count as unread
          make_comment(user, @threads["t1"], "my two cents")
          rs = thread_result course_id: "abc", user_id: "123", sort_order: "asc"
          rs[0]["unread_comments_count"].should == 0

          # other's posts do, though
          make_comment(@threads["t1"].author, @threads["t1"], "the last word")
          rs = thread_result course_id: "abc", user_id: "123", sort_order: "asc"
          rs[0]["unread_comments_count"].should == 1
        end

        context "sorting" do
          def thread_result_order (sort_key, sort_order)
            results = thread_result course_id: DFLT_COURSE_ID, sort_key: sort_key, sort_order: sort_order
            results.length.should == 10 
            results.map {|t| t["title"]}
          end

          def move_to_end(ary, *vals)
            vals.each do |val|
              ary = ary.select {|v| v!=val } << val
            end
            ary
          end

          def move_to_front(ary, *vals)
            vals.reverse.each do |val|
              ary = ary.select {|v| v!=val }.insert(0, val)
            end
            ary
          end

          it "sorts using create date / ascending" do
            actual_order = thread_result_order("date", "asc")
            expected_order = @default_order.reverse
            actual_order.should == expected_order
          end
          it "sorts using create date / descending" do
            actual_order = thread_result_order("date", "desc")
            expected_order = @default_order
            actual_order.should == expected_order
          end
          it "sorts using last activity / descending" do
            t5c = @threads["t5"].comments.first
            t5c.update(body: "changed!")
            t5c.save!
            actual_order = thread_result_order("activity", "desc")
            expected_order = move_to_front(@default_order, "t5") 
            actual_order.should == expected_order
          end
          it "sorts using last activity / ascending" do
            t5c = @threads["t5"].comments.first
            t5c.update(body: "changed!")
            t5c.save!
            actual_order = thread_result_order("activity", "asc")
            expected_order = move_to_end(@default_order.reverse, "t5") 
            actual_order.should == expected_order
          end
          it "sorts using vote count / descending" do
            user = User.all.first
            t5 = @threads["t5"]
            user.vote(t5, :up)
            t5.save!
            actual_order = thread_result_order("votes", "desc")
            expected_order = move_to_front(@default_order, "t5") 
            actual_order.should == expected_order
          end
          it "sorts using vote count / ascending" do
            user = User.all.first
            t5 = @threads["t5"]
            user.vote(t5, :up)
            t5.save!
            actual_order = thread_result_order("votes", "asc")
            expected_order = move_to_end(@default_order, "t5") 
            actual_order.should == expected_order
          end
          it "sorts using comment count / descending" do
            make_comment(@threads["t5"].author, @threads["t5"], "extra comment")
            actual_order = thread_result_order("comments", "desc")
            expected_order = move_to_front(@default_order, "t5") 
            actual_order.should == expected_order
          end
          it "sorts using comment count / ascending" do
            make_comment(@threads["t5"].author, @threads["t5"], "extra comment")
            actual_order = thread_result_order("comments", "asc")
            expected_order = move_to_end(@default_order, "t5") 
            actual_order.should == expected_order
          end
          it "sorts pinned items first" do
            make_comment(@threads["t5"].author, @threads["t5"], "extra comment")
            @threads["t7"].pinned = true
            @threads["t7"].save!

            actual_order = thread_result_order("comments", "asc")
            expected_order = move_to_front(move_to_end(@default_order, "t5"), "t7")
            actual_order.should == expected_order

            actual_order = thread_result_order("comments", "desc")
            expected_order = move_to_front(move_to_front(@default_order, "t5"), "t7")
            actual_order.should == expected_order

            @threads["t8"].pinned = true
            @threads["t8"].save!

            actual_order = thread_result_order("comments", "asc")
            expected_order = move_to_front(move_to_end(@default_order, "t5"), "t8", "t7")
            actual_order.should == expected_order

            actual_order = thread_result_order("date", "desc")
            expected_order = move_to_front(@default_order, "t8", "t7")
            actual_order.should == expected_order

            actual_order = thread_result_order("date", "asc")
            expected_order = move_to_front(@default_order.reverse, "t7", "t8")
            actual_order.should == expected_order
          end
          
          context "pagination" do
            def thread_result_page (sort_key, sort_order, page, per_page, user_id=nil, unread=false)
              get "/api/v1/threads", course_id: DFLT_COURSE_ID, sort_key: sort_key, sort_order: sort_order, page: page, per_page: per_page, user_id: user_id, unread: unread
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

            def test_paged_order (sort_spec, expected_order, filter_spec=[], user_id=nil)
              # sort spec is a hash with keys: sort_key, sort_dir, per_page
              # filter spec is an array of filters to set, e.g. "unread", "flagged"
              # expected order is an array of the expected titles of returned threads, in the expected order
              actual_order = []
              per_page = sort_spec['per_page']
              num_pages = (expected_order.length + per_page - 1) / per_page
              num_pages.times do |i|
                page = i + 1
                result = thread_result_page(
                  sort_spec['sort_key'],
                  sort_spec['sort_dir'],
                  page,
                  per_page,
                  user_id,
                  filter_spec.include?("unread")
                )
                result["collection"].length.should == (page * per_page <= expected_order.length ? per_page : expected_order.length % per_page)
                if filter_spec.include?("unread")
                  # because of the way we handle num_pages for the unread filter, this is a special case.
                  result["num_pages"].should == (page == num_pages ? page : page + 1)
                else
                  result["num_pages"].should == num_pages
                end
                result["page"].should == page
                actual_order += result["collection"].map {|v| v["title"]}
              end
              actual_order.should == expected_order
            end

            it "orders correctly across pages" do
              make_comment(@threads["t5"].author, @threads["t5"], "extra comment")
              @threads["t7"].pinned = true
              @threads["t7"].save!
              expected_order = move_to_front(move_to_end(@default_order, "t5"), "t7")
              test_paged_order({'sort_key'=>'comments', 'sort_dir'=>'asc', 'per_page'=>3}, expected_order)
            end

            it "orders correctly acrosss pages with unread filter" do
              user = create_test_user(Random.new)
              user.mark_as_read(@threads["t0"])
              user.mark_as_read(@threads["t9"])
              make_comment(@threads["t5"].author, @threads["t5"], "extra comment")
              @threads["t7"].pinned = true
              @threads["t7"].save!
              expected_order = move_to_front(move_to_end(@default_order[1..8], "t5"), "t7")
              test_paged_order(
                {'sort_key'=>'comments', 'sort_dir'=>'asc', 'per_page'=>3},
                expected_order,
                ["unread"],
                user.id
              )
            end
          end
        end
        
      end

      def test_unicode_data(text)
        course_id = "unicode_course"
        thread = make_thread(User.first, text, course_id, "unicode_commentable")
        make_comment(User.first, thread, text)
        result = thread_result(course_id: course_id).first
        check_thread_result_json(nil, thread, result)
      end

      include_examples "unicode data"
    end

    describe "GET /api/v1/threads/:thread_id" do

      before(:each) { init_without_subscriptions }
      
      it "returns JSON" do
        thread = CommentThread.first
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        last_response.content_type.should == "application/json;charset=utf-8"
      end

      it "get information of a single comment thread" do
        thread = CommentThread.first
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        check_thread_result_json(nil, thread, response_thread)
      end

      it "computes endorsed correctly" do
        thread = CommentThread.first
        comment = thread.root_comments[1]
        comment.endorsed = true
        comment.save!
        get "/api/v1/threads/#{thread.id}"
        last_response.should be_ok
        response_thread = parse last_response.body
        response_thread["endorsed"].should == true
        check_thread_result_json(nil, thread, response_thread)
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
        check_thread_result_json(nil, thread, parse(last_response.body))
        check_thread_response_paging_json(thread, parse(last_response.body))
      end

      it "returns 404 when the thread does not exist" do
        thread = CommentThread.first
        path = "/api/v1/threads/#{thread.id}"
        get path
        last_response.should be_ok
        thread.destroy
        get path
        last_response.status.should == 404
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end

      def test_unicode_data(text)
        thread = make_thread(User.first, text, "unicode_course", "unicode_commentable")
        make_comment(User.first, thread, text)
        get "/api/v1/threads/#{thread.id}", recursive: true
        last_response.should be_ok
        result = parse last_response.body
        check_thread_result_json(nil, thread, result)
        check_thread_response_paging_json(thread, result)
      end

      include_examples "unicode data"

      context "response pagination" do

        before(:each) do
          User.all.delete
          Content.all.delete
          @user = create_test_user(999)
          @threads = {}
          @comments = {}
          [20,10,3,2,1,0].each do |n|
            thread_key = "t#{n}"
            thread = make_thread(@user, thread_key, DFLT_COURSE_ID, "pdq")
            @threads[n] = thread
            n.times do |i|
              # generate n responses in this thread
              comment_key = "#{thread_key} r#{i}"
              comment = make_comment(@user, thread, comment_key)
              i.times do |j|
                subcomment_key = "#{comment_key} c#{j}"
                subcomment = make_comment(@user, comment, subcomment_key)
              end
              @comments[comment_key] = comment
            end
          end
        end

        def thread_result(id, params)
          get "/api/v1/threads/#{id}", params
          last_response.should be_ok
          parse(last_response.body)
        end

        it "returns all responses when no skip/limit params given" do
          @threads.each do |n, thread|
            res = thread_result thread.id, {}
            check_thread_response_paging_json thread, res
          end 
        end

        it "skips the specified number of responses" do
          @threads.each do |n, thread|
            res = thread_result thread.id, {:resp_skip => 1}
            check_thread_response_paging_json thread, res, 1, nil
          end 
        end

        it "limits the specified number of responses" do
          @threads.each do |n, thread|
            res = thread_result thread.id, {:resp_limit => 2}
            check_thread_response_paging_json thread, res, 0, 2
          end 
        end

        it "skips and limits responses" do
          @threads.each do |n, thread|
            res = thread_result thread.id, {:resp_skip => 3, :resp_limit => 5}
            check_thread_response_paging_json thread, res, 3, 5
          end 
        end

      end
    end

    describe "PUT /api/v1/threads/:thread_id" do

      before(:each) { init_without_subscriptions }
      
      it "update information of comment thread" do
        thread = CommentThread.first
        comment = thread.comments.first
        comment.endorsed = true
        comment.endorsement = {:user_id => "42", :time => DateTime.now}
        comment.save
        put "/api/v1/threads/#{thread.id}", body: "new body", title: "new title", commentable_id: "new_commentable_id", thread_type: "question"
        last_response.should be_ok
        changed_thread = CommentThread.find(thread.id)
        changed_thread.body.should == "new body"
        changed_thread.title.should == "new title"
        changed_thread.commentable_id.should == "new_commentable_id"
        changed_thread.thread_type.should == "question"
        comment.reload
        comment.endorsed.should == false
        comment.endorsement.should == nil
        check_thread_result_json(nil, changed_thread, parse(last_response.body))
      end
      it "returns 400 when the thread does not exist" do
        put "/api/v1/threads/does_not_exist", body: "new body", title: "new title"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
      it "returns 503 and does not update if the post body has been blocked" do
        thread = CommentThread.first
        original_body = thread.body
        put "/api/v1/threads/#{thread.id}", body: "BLOCKED POST", title: "new title", commentable_id: "new_commentable_id"
        last_response.status.should == 503
        thread.reload
        thread.body.should == original_body
        put "/api/v1/threads/#{thread.id}", body: "blocked,   post...", title: "new title", commentable_id: "new_commentable_id"
        last_response.status.should == 503
        thread.reload
        thread.body.should == original_body
      end

      def test_unicode_data(text)
        thread = CommentThread.first
        put "/api/v1/threads/#{thread.id}", body: text, title: text
        last_response.should be_ok
        thread.body.should == text
        thread.title.should == text
      end

      include_examples "unicode data"
    end
    describe "POST /api/v1/threads/:thread_id/comments" do

      before(:each) { init_without_subscriptions }

      let :default_params  do
        {body: "new comment", course_id: "1", user_id: User.first.id}
      end
      it "create a comment to the comment thread" do
        thread = CommentThread.first
        user = User.first
        orig_count = thread.comment_count
        post "/api/v1/threads/#{thread.id}/comments", default_params
        last_response.should be_ok
        changed_thread = CommentThread.find(thread.id)
        changed_thread.comment_count.should == orig_count + 1
        comment = changed_thread.comments.select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment.author_id.should == user.id
      end
      it "allows anonymous comment" do
        thread = CommentThread.first
        user = User.first
        orig_count = thread.comment_count
        post "/api/v1/threads/#{thread.id}/comments", default_params.merge(anonymous: true)
        last_response.should be_ok
        changed_thread = CommentThread.find(thread.id)
        changed_thread.comment_count.should == orig_count + 1
        comment = changed_thread.comments.select{|c| c["body"] == "new comment"}.first
        comment.should_not be_nil
        comment.anonymous.should be_true
      end
      it "returns 400 when the thread does not exist" do
        post "/api/v1/threads/does_not_exist/comments", default_params
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
      it "returns error when body or course_id does not exist, or when body is blank" do
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(body: nil)
        last_response.status.should == 400
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(course_id: nil)
        last_response.status.should == 400
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(body: "    \n      \n  ")
        last_response.status.should == 400
      end
      it "returns 503 and does not create when the post body has been blocked" do
        post "/api/v1/threads/#{CommentThread.first.id}/comments", default_params.merge(body: "BLOCKED POST")
        last_response.status.should == 503
        Comment.where(body: "BLOCKED POST").to_a.should be_empty
      end

      def test_unicode_data(text)
        thread = CommentThread.first
        post "/api/v1/threads/#{thread.id}/comments", default_params.merge(body: text)
        last_response.should be_ok
        thread.comments.where(body: text).should_not be_empty
      end

      include_examples "unicode data"
    end
    describe "DELETE /api/v1/threads/:thread_id" do
      before(:each) { init_without_subscriptions }
      it "delete the comment thread and its comments" do
        thread = CommentThread.first.to_hash
        delete "/api/v1/threads/#{thread['id']}"
        last_response.should be_ok
        CommentThread.where(title: thread["title"]).first.should be_nil
      end
      it "returns 400 when the thread does not exist" do
        delete "/api/v1/threads/does_not_exist"
        last_response.status.should == 400
        parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
      end
    end
  end
end
