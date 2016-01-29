require 'spec_helper'
require 'unicode_shared_examples'

describe "app" do
  describe "users" do
    before :each do
      User.delete_all
      create_test_user 1
      create_test_user 2
      set_api_key_header
    end
    describe "POST /api/v1/users" do
      it "creates a user" do
        post "/api/v1/users", id: "100", username: "user100"
        last_response.should be_ok
        user = User.find_by(external_id: "100")
        user.username.should == "user100"
      end
      it "returns error when id / username already exists" do
        post "/api/v1/users", id: "1", username: "user100"
        last_response.status.should == 400
        post "/api/v1/users", id: "100", username: "user1"
        last_response.status.should == 400
      end
    end
    describe "PUT /api/v1/users/:user_id" do
      it "updates user information" do
        put "/api/v1/users/1", username: "new_user_1"
        last_response.should be_ok
        user = User.find_by("1")
        user.username.should == "new_user_1"
      end
      it "does not update id" do
        put "/api/v1/users/1", id: "100"
        last_response.should be_ok
        user = User.find_by("1")
        user.should_not be_nil
      end
      it "returns error if user does not exist" do
        put "/api/v1/users/100", id: "100"
        last_response.status.should == 400
      end
      it "returns error if new information has conflict with other users" do
        put "/api/v1/users/1", username: "user2"
        last_response.status.should == 400 
      end
    end
    describe "GET /api/v1/users/:user_id" do
      it "returns user information" do
        get "/api/v1/users/1"
        last_response.status.should == 200
        res = parse(last_response.body)
        user1 = User.find_by("1")
        res["external_id"].should == user1.external_id
        res["username"].should == user1.username
      end
      it "returns 404 if user does not exist" do
        get "/api/v1/users/3"
        last_response.status.should == 404
      end
      describe "Returns threads_count and comments_count" do
          before(:each) { setup_10_threads }

          def create_thread_and_comment_in_specific_group(user_id, group_id, thread)
             # Changes the specified thread and a comment within that thread to be authored by the
             # specified user in the specified group_id.
             @threads[thread].author = @users["u"+user_id]
             @threads[thread].group_id = group_id
             @threads[thread].save!
             first_comment_in_thread = thread + " c1"
             @comments[first_comment_in_thread].author = @users["u"+user_id]
             @comments[first_comment_in_thread].save!
          end

          def verify_counts(expected_threads, expected_comments, user_id, group_id=nil)
             if group_id
                get "/api/v1/users/" + user_id, course_id: "xyz", group_id: group_id
             else
                get "/api/v1/users/" + user_id, course_id: "xyz"
             end
             parse_response_and_verify_counts(expected_threads, expected_comments)
          end

          def verify_counts_multiple_groups(expected_threads, expected_comments, user_id, group_ids)
             get "/api/v1/users/" + user_id, course_id: "xyz", group_ids: group_ids
             parse_response_and_verify_counts(expected_threads, expected_comments)
          end

          def parse_response_and_verify_counts(expected_threads, expected_comments)
             res = parse(last_response.body)
             res["threads_count"].should == expected_threads
             res["comments_count"].should == expected_comments
          end

          it "returns threads_count and comments_count" do
             # "setup_10_threads" creates 1 thread ("t0") and 5 comments (in "t0") authored by user 100.
             verify_counts(1, 5, "100")
          end

          it "returns threads_count and comments_count irrespective of group_id, if group_id is not specified" do
             # Now change thread "t1" and comment in "t1" to be authored by user 100, but in a group (43).
             # As long as we don't ask for user info for a specific group, these will always be included.
             create_thread_and_comment_in_specific_group("100", 43, "t1")
             verify_counts(2, 6, "100")
          end

          it "returns threads_count and comments_count filtered by group_id, if group_id is specified" do
             create_thread_and_comment_in_specific_group("100", 43, "t1")

             # The threads and comments created by "setup_10_threads" do not have a group_id specified, so are
             # visible to all (group_id=3000 specified).
             verify_counts(1, 5, "100", 3000)

             # There is one additional thread and comment (created by create_thread_and_comment_in_specific_group),
             # visible to only group_id 43.
             verify_counts(2, 6, "100", 43)
          end

          it "handles comments correctly on threads not started by the author" do
             # "setup_10_threads" creates 1 thread ("t1") and 5 comments (in "t1") authored by user 101.
             verify_counts(1, 5, "101")

             # The next call makes user 100 the author of "t1" and "t1 c1" (within group_id 43).
             create_thread_and_comment_in_specific_group("100", 43, "t1")

             # Therefore user 101 is now just the author of 4 comments.
             verify_counts(0, 4, "101")

             # We should get the same comment count when specifically asking for comments within group_id 43.
             verify_counts(0, 4, "101", 43)

             # We should get no comments for a different group.
             verify_counts(0, 0, "101", 3000)
          end

          it "can return comments and threads for multiple groups" do
             create_thread_and_comment_in_specific_group("100", 43, "t1")
             create_thread_and_comment_in_specific_group("100", 3000, "t2")

             # user 100 is now the author of:
             #    visible to all groups-- 1 thread ("t0") and 5 comments
             #    visible to group_id 43-- 1 thread ("t1") and 1 comment
             #    visible to group_id 3000-- 1 thread ("t2") and 1 comment
             verify_counts(3, 7, "100")
             verify_counts_multiple_groups(3, 7, "100", "")
             verify_counts_multiple_groups(3, 7, "100", "43, 3000")
             verify_counts_multiple_groups(3, 7, "100", "43, 3000, 8")
             verify_counts_multiple_groups(2, 6, "100", "43")
             verify_counts_multiple_groups(2, 6, "100", "3000")
             verify_counts_multiple_groups(1, 5, "100", "8")
          end

          context "standalone threads" do
            before(:each) do
              # creates a standalone thread with 3 comments by user 100
              make_standalone_thread_with_comments(@users['u100'])
            end

            it 'does not return standalone thread or comments in counts' do
              # user 100 already has 1 thread and 5 comments created by `setup_10_threads`
              # verify that the new standalone thread is not added to the counts
              verify_counts(1, 5, "100")
            end
          end
      end
    end
    describe "GET /api/v1/users/:user_id/active_threads" do

      before(:each) { setup_10_threads }

      def thread_result(user_id, params)
        get "/api/v1/users/#{user_id}/active_threads", params
        last_response.should be_ok
        parse(last_response.body)["collection"]
      end

      it "requires that a course id be passed" do
        get "/api/v1/users/100/active_threads"
        # this is silly, but it is the legacy behavior
        last_response.should be_ok
        last_response.body.should == "{}"
      end

      context 'with standalone thread' do
        before(:each) do
          # creates a standalone thread with 3 comments by user 100, stored as "standalone t0 c{i}"
          make_standalone_thread_with_comments(@users['u100'], 0)
          # creates a standalone thread with 3 comments by user 101, with stored as "standalone t0 c{i}"
          make_standalone_thread_with_comments(@users['u101'], 1)
        end

        it "only returns threads with non-standalone activity from the specified user"  do
          # `setup_10_threads` creates a thread "t3" and 5 comments all owned by user 103 
          # we are hijacking a course thread comment owned by user 103 and making it owned
          # by user 100 instead, so this user has a comment on someone else's thread
          @comments["t3 c4"].author = @users["u100"]
          @comments["t3 c4"].save!

          # do the same as above but with standalone
          # hijack a standalone thread comment and make it owned by user 100
          @comments["standalone t1 c1"].author = @users["u100"]
          @comments["standalone t1 c1"].save!

          results = thread_result 100, course_id: "xyz"
          # it should not include the standalone thread we created for user 100
          # not the standalone thread user 100 is a commenter on
          results.length.should == 2

          # it should include the course thread owned by user 100 (t0)
          # and the course thread user 100 has a comment on (t3)
          check_thread_result_json(@users["u100"], @threads["t3"], results[0])
          check_thread_result_json(@users["u100"], @threads["t0"], results[1])
        end
      end

      it "filters by group_id" do
        @threads["t1"].author = @users["u100"]
        @threads["t1"].save!
        rs = thread_result 100, course_id: DFLT_COURSE_ID, group_id: 42
        rs.length.should == 2
        @threads["t1"].group_id = 43
        @threads["t1"].save!
        rs = thread_result 100, course_id: DFLT_COURSE_ID, group_id: 42
        rs.length.should == 1
        @threads["t1"].group_id = 42
        @threads["t1"].save!
        rs = thread_result 100, course_id: DFLT_COURSE_ID, group_id: 42
        rs.length.should == 2
      end

      it "filters by group_ids" do
        @threads["t1"].author = @users["u100"]
        @threads["t1"].save!
        rs = thread_result 100, course_id: DFLT_COURSE_ID, group_ids: "42"
        rs.length.should == 2
        @threads["t1"].group_id = 43
        @threads["t1"].save!
        rs = thread_result 100, course_id: DFLT_COURSE_ID, group_ids: "42"
        rs.length.should == 1
        rs = thread_result 100, course_id: DFLT_COURSE_ID, group_ids: "42,43"
        rs.length.should == 2
      end

      it "does not return threads in which the user has only participated anonymously" do
        @comments["t3 c4"].author = @users["u100"]
        @comments["t3 c4"].anonymous_to_peers = true
        @comments["t3 c4"].save!
        @comments["t5 c1"].author = @users["u100"]
        @comments["t5 c1"].anonymous = true
        @comments["t5 c1"].save!
        rs = thread_result 100, course_id: "xyz"
        rs.length.should == 1
        check_thread_result_json(@users["u100"], @threads["t0"], rs.first)
      end      

      it "only returns threads from the specified course" do
        @threads.each do |k, v|
          v.author = @users["u100"]
          v.save!
        end
        @threads["t9"].course_id = "zzz"
        @threads["t9"].save!
        rs = thread_result 100, course_id: "xyz"
        rs.length.should == 9
      end

      it "correctly orders results by most recent update by selected user" do
        user = @users["u100"]
        base_time = DateTime.now
        @comments["t2 c2"].author = user
        @comments["t2 c2"].updated_at = base_time
        @comments["t2 c2"].save!
        @comments["t4 c4"].author = user
        @comments["t4 c4"].updated_at = base_time + 1
        @comments["t4 c4"].save!
        @threads["t2"].updated_at = base_time + 2
        @threads["t2"].save!
        @threads["t3"].author = user
        @threads["t3"].updated_at = base_time + 4
        @threads["t3"].save!
        rs = thread_result 100, course_id: "xyz"
        actual_order = rs.map {|v| v["title"]}
        actual_order.should == ["t3", "t4", "t2", "t0"]
      end

      context "pagination" do
        def thread_result_page (page, per_page)
          get "/api/v1/users/100/active_threads", course_id: "xyz", page: page, per_page: per_page
          last_response.should be_ok
          parse(last_response.body)
        end

        before(:each) do
          @comments.each do |k, v|
            @comments[k].author = @users["u100"]
            @comments[k].save!
          end
        end

        it "returns single page" do
          result = thread_result_page(1, 20)
          result["collection"].length.should == 10
          result["num_pages"].should == 1
          result["page"].should == 1
        end
        it "returns multiple pages" do
          result = thread_result_page(1, 5)
          result["collection"].length.should == 5
          result["num_pages"].should == 2
          result["page"].should == 1

          result = thread_result_page(2, 5)
          result["collection"].length.should == 5
          result["num_pages"].should == 2
          result["page"].should == 2
        end
        it "orders correctly across pages" do
          expected_order = @threads.keys.reverse 
          actual_order = []
          per_page = 3
          num_pages = (@threads.length + per_page - 1) / per_page
          num_pages.times do |i|
            page = i + 1
            result = thread_result_page(page, per_page)
            result["collection"].length.should == (page * per_page <= @threads.length ? per_page : @threads.length % per_page)
            result["num_pages"].should == num_pages
            result["page"].should == page
            actual_order += result["collection"].map {|v| v["title"]}
          end
          actual_order.should == expected_order
        end
        it "accepts negative parameters" do
          result = thread_result_page(-5, -5)
          result["collection"].length.should == 10
          result["num_pages"].should == 1
          result["page"].should == 1
        end
        it "accepts excessively large parameters" do
          result = thread_result_page(9999, 9999)
          result["collection"].length.should == 10
          result["num_pages"].should == 1
          result["page"].should == 1
        end
        it "accepts empty parameters" do
          result = thread_result_page("", "")
          result["collection"].length.should == 10
          result["num_pages"].should == 1
          result["page"].should == 1
        end
      end

      def test_unicode_data(text)
        user = User.first
        course_id = "unicode_course"
        thread = make_thread(user, text, course_id, "unicode_commentable")
        make_comment(user, thread, text)
        result = thread_result(user.id, course_id: course_id)
        result.length.should == 1
        check_thread_result_json(nil, thread, result.first)
      end

      include_examples "unicode data"
    end
  end
end
