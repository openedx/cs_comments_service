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
        expect(last_response).to be_ok
        user = User.find_by(external_id: "100")
        expect(user.username).to eq("user100")
      end
      it "returns error when id / username already exists" do
        post "/api/v1/users", id: "1", username: "user100"
        expect(last_response.status).to eq(400)
        post "/api/v1/users", id: "100", username: "user1"
        expect(last_response.status).to eq(400)
      end
    end
    describe "PUT /api/v1/users/:user_id" do
      it "updates user information" do
        put "/api/v1/users/1", username: "new_user_1"
        expect(last_response).to be_ok
        user = User.find_by("1")
        expect(user.username).to eq("new_user_1")
      end
      it "does not update id" do
        put "/api/v1/users/1", id: "100"
        expect(last_response).to be_ok
        user = User.find_by("1")
        expect(user).not_to be_nil
      end
      it "returns error if user does not exist" do
        put "/api/v1/users/100", id: "100"
        expect(last_response.status).to eq(400)
      end
      it "returns error if new information has conflict with other users" do
        put "/api/v1/users/1", username: "user2"
        expect(last_response.status).to eq(400)
      end
    end

    describe "GET /api/v1/users/:user_id" do
      let(:author) { User.find_by(external_id: "1") }
      let(:reader) { User.find_by(external_id: "2") }
      let(:thread) { make_standalone_thread(author) }

      it "returns user information" do
        get "/api/v1/users/1"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        user1 = User.find_by("1")
        expect(res["external_id"]).to eq(user1.external_id)
        expect(res["username"]).to eq(user1.username)
      end

      it "returns 404 if user does not exist" do
        get "/api/v1/users/3"
        expect(last_response.status).to eq(404)
      end

      it "returns no threads when user hasn't voted" do
        get "/api/v1/users/1", complete: "true"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["upvoted_ids"]).to eq([])
      end

      it "returns threads when user votes" do
        reader.vote(thread, :up)

        get "/api/v1/users/2", complete: "true"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["upvoted_ids"]).to eq([thread.id.to_s])
      end

      describe "Returns threads_count and comments_count" do
        before(:each) { setup_10_threads }

        def create_thread_and_comment_in_specific_group(user_id, group_id, thread)
          # Changes the specified thread and a comment within that thread to be authored by the
          # specified user in the specified group_id.
          @threads[thread].author = @users["u" + user_id]
          @threads[thread].group_id = group_id
          @threads[thread].save!
          first_comment_in_thread = thread + " c1"
          @comments[first_comment_in_thread].author = @users["u" + user_id]
          @comments[first_comment_in_thread].save!
        end

        def verify_counts(expected_threads, expected_comments, user_id, group_id = nil)
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
          expect(res["threads_count"]).to eq(expected_threads)
          expect(res["comments_count"]).to eq(expected_comments)
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
        expect(last_response).to be_ok
        parse(last_response.body)["collection"]
      end

      it "requires that a course id be passed" do
        get "/api/v1/users/100/active_threads"
        # this is silly, but it is the legacy behavior
        expect(last_response).to be_ok
        expect(last_response.body).to eq("{}")
      end

      context 'with standalone thread' do
        before(:each) do
          # creates a standalone thread with 3 comments by user 100, stored as "standalone t0 c{i}"
          make_standalone_thread_with_comments(@users['u100'], 0)
          # creates a standalone thread with 3 comments by user 101, with stored as "standalone t0 c{i}"
          make_standalone_thread_with_comments(@users['u101'], 1)
        end

        it "only returns threads with non-standalone activity from the specified user" do
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
          expect(results.length).to eq(2)

          # it should include the course thread owned by user 100 (t0)
          # and the course thread user 100 has a comment on (t3)
          check_thread_result_json(@users["u100"], @threads["t3"], results[0])
          check_thread_result_json(@users["u100"], @threads["t0"], results[1])
        end
      end

      context 'filtering' do

        it "filters by unread", :new => true do
          # All 10 threads are are assigned to the requesting user
          (1...10).each { |tid|
            @threads["t#{tid}"].author = @users["u100"]
            @threads["t#{tid}"].save!
          }
          # However one of them is marked as read
          @users["u100"].mark_as_read(@threads["t3"])
          # The results should include 9 entries, and exclude t3 which is marked as read.
          rs = thread_result 100, course_id: DFLT_COURSE_ID, unread: true, per_page: 5
          expect(rs.length).to eq(5)
          expect(rs).not_to include have_attributes(:title => "t3")
          rs2 = thread_result 100, course_id: DFLT_COURSE_ID, unread: true, per_page: 5, page: 2
          expect(rs2.length).to eq(4)
          expect(rs2).not_to include have_attributes(:title => "t3")
        end

        it "filters by group_id" do
          @threads["t1"].author = @users["u100"]
          @threads["t1"].save!
          rs = thread_result 100, course_id: DFLT_COURSE_ID, group_id: 42
          expect(rs.length).to eq(2)
          @threads["t1"].group_id = 43
          @threads["t1"].save!
          rs = thread_result 100, course_id: DFLT_COURSE_ID, group_id: 42
          expect(rs.length).to eq(1)
          @threads["t1"].group_id = 42
          @threads["t1"].save!
          rs = thread_result 100, course_id: DFLT_COURSE_ID, group_id: 42
          expect(rs.length).to eq(2)
        end

        it "filters by group_ids" do
          @threads["t1"].author = @users["u100"]
          @threads["t1"].save!
          rs = thread_result 100, course_id: DFLT_COURSE_ID, group_ids: "42"
          expect(rs.length).to eq(2)
          @threads["t1"].group_id = 43
          @threads["t1"].save!
          rs = thread_result 100, course_id: DFLT_COURSE_ID, group_ids: "42"
          expect(rs.length).to eq(1)
          rs = thread_result 100, course_id: DFLT_COURSE_ID, group_ids: "42,43"
          expect(rs.length).to eq(2)
        end

        it "does not return threads in which the user has only participated anonymously" do
          @comments["t3 c4"].author = @users["u100"]
          @comments["t3 c4"].anonymous_to_peers = true
          @comments["t3 c4"].save!
          @comments["t5 c1"].author = @users["u100"]
          @comments["t5 c1"].anonymous = true
          @comments["t5 c1"].save!
          rs = thread_result 100, course_id: "xyz"
          expect(rs.length).to eq(1)
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
          expect(rs.length).to eq(9)
        end

      end

      context "sorting" do

        before(:each) do
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
          @threads["t11"] = setup_thread_with_comments user, "t11", 7
          @threads["t12"] = setup_thread_with_comments user, "t12", 9
          @threads["t13"] = setup_thread_with_comments user, "t13", 3
          @threads["t11"].created_at = base_time - 10
          @threads["t11"].save!
          user.vote(@threads["t2"], :up)
          user.vote(@threads["t11"], :up)
          @users["u101"].vote @threads["t11"], :up
          make_comment user, @threads["t2"], Faker::Lorem.sentence
        end

        it "correctly orders results by default order" do
          rs = thread_result 100, course_id: "xyz"
          actual_order = rs.map { |v| v["title"] }
          expect(actual_order).to eq(%w[t3 t4 t2 t11 t13 t12 t0])
        end

        it "correctly orders results by most recent update by selected user" do
          rs = thread_result 100, { course_id: "xyz", sort_key: "user_activity" }
          actual_order = rs.map { |v| v["title"] }
          expect(actual_order).to eq(%w[t3 t4 t2 t11 t13 t12 t0])
        end

        it "correctly orders results by most recent update by date" do
          rs = thread_result 100, { course_id: "xyz", sort_key: "date" }
          actual_order = rs.map { |v| v["title"] }
          expect(actual_order).to eq(%w[t13 t12 t4 t3 t2 t0 t11])
        end

        it "correctly orders results by most recent update by activity" do
          rs = thread_result 100, { course_id: "xyz", sort_key: "activity" }
          actual_order = rs.map { |v| v["title"] }
          expect(actual_order).to eq(%w[t2 t13 t12 t11 t4 t3 t0])
        end

        it "correctly orders results by most recent update by votes" do
          rs = thread_result 100, { course_id: "xyz", sort_key: "votes" }
          actual_order = rs.map { |v| v["title"] }
          expect(actual_order).to eq(%w[t11 t2 t13 t12 t4 t3 t0])
        end

        it "correctly orders results by most recent update by comments" do
          rs = thread_result 100, { course_id: "xyz", sort_key: "comments" }
          actual_order = rs.map { |v| v["title"] }
          expect(actual_order).to eq(%w[t12 t11 t2 t4 t3 t0 t13])
        end

      end

      context "pagination" do
        def thread_result_page (page, per_page)
          get "/api/v1/users/100/active_threads", course_id: "xyz", page: page, per_page: per_page
          expect(last_response).to be_ok
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
          expect(result["collection"].length).to eq(10)
          expect(result["num_pages"]).to eq(1)
          expect(result["page"]).to eq(1)
        end
        it "returns multiple pages" do
          result = thread_result_page(1, 5)
          expect(result["collection"].length).to eq(5)
          expect(result["num_pages"]).to eq(2)
          expect(result["page"]).to eq(1)

          result = thread_result_page(2, 5)
          expect(result["collection"].length).to eq(5)
          expect(result["num_pages"]).to eq(2)
          expect(result["page"]).to eq(2)
        end
        it "orders correctly across pages" do
          expected_order = @threads.keys.reverse
          actual_order = []
          per_page = 3
          num_pages = (@threads.length + per_page - 1) / per_page
          num_pages.times do |i|
            page = i + 1
            result = thread_result_page(page, per_page)
            expect(result["collection"].length).to eq((page * per_page <= @threads.length ? per_page : @threads.length % per_page))
            expect(result["num_pages"]).to eq(num_pages)
            expect(result["page"]).to eq(page)
            actual_order += result["collection"].map { |v| v["title"] }
          end
          expect(actual_order).to eq(expected_order)
        end
        it "accepts negative parameters" do
          result = thread_result_page(-5, -5)
          expect(result["collection"].length).to eq(10)
          expect(result["num_pages"]).to eq(1)
          expect(result["page"]).to eq(1)
        end
        it "accepts empty parameters" do
          result = thread_result_page("", "")
          expect(result["collection"].length).to eq(10)
          expect(result["num_pages"]).to eq(1)
          expect(result["page"]).to eq(1)
        end
      end

      def test_unicode_data(text)
        user = User.first
        course_id = "unicode_course"
        thread = make_thread(user, text, course_id, "unicode_commentable")
        make_comment(user, thread, text)
        result = thread_result(user.id, course_id: course_id)
        expect(result.length).to eq(1)
        check_thread_result_json(nil, thread, result.first)
      end

      include_examples "unicode data"
    end

    def add_flags(content, expected_data)
      # Add a random number of abuse flaggers (0 to 2) and historical abuse flaggers
      content.abuse_flaggers = (1..Random.rand(3)).to_a
      content.historical_abuse_flaggers = (1..Random.rand(2)).to_a
      content.save!
      # If any flaggers were added, increment the count of reports for the user
      expected_data[content.author.external_id]["active_flags"] += content.abuse_flaggers.empty? ? 0 : 1
      expected_data[content.author.external_id]["inactive_flags"] += content.historical_abuse_flaggers.empty? ? 0 : 1
    end

    def build_structure_and_response(course_id, authors, build_initial_stats = true, with_timestamps = false)
      Timecop.scale(1000)
      expected_data = Hash[authors.map { |author| [
        author.external_id,
        {
          "username" => author.username,
          "active_flags" => 0,
          "inactive_flags" => 0,
          "threads" => 0,
          "responses" => 0,
          "replies" => 0,
        }
      ]
      }]
      # Create 10 random threads with random authors
      (0..10).each do
        thread_author = authors.sample
        expected_data[thread_author.external_id]["threads"] += 1
        expected_data[thread_author.external_id]["last_activity_at"] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ") if with_timestamps
        thread = make_thread(thread_author, Faker::Lorem.sentence, course_id, Faker::Lorem.word)
        add_flags(thread, expected_data)
        # For each thread create 5 random comments with random authors
        (0..5).each do
          comment_author = authors.sample
          expected_data[comment_author.external_id]["responses"] += 1
          expected_data[comment_author.external_id]["last_activity_at"] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ") if with_timestamps
          comment = make_comment(comment_author, thread, Faker::Lorem.sentence)
          add_flags(comment, expected_data)
          # For each comment create 3 random replies with random authors
          (0..2).each do
            reply_author = authors.sample
            expected_data[reply_author.external_id]["replies"] += 1
            expected_data[reply_author.external_id]["last_activity_at"] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ") if with_timestamps
            reply = make_comment(reply_author, comment, Faker::Lorem.sentence)
            add_flags(reply, expected_data)
          end
        end
      end
      if build_initial_stats
        authors.map { |author| author.build_course_stats(course_id) }
      end
      Timecop.return
      expected_data
    end

    describe "GET /api/v1/users/:course_id/stats" do

      let(:course_id) { Faker::Lorem.word }
      let(:authors) { %w[author-1 author-2 author-3 author-4 author-5 author-6].map { |id| create_test_user(id) } }

      before(:each) do
        build_structure_and_response Faker::Lorem.word, authors
      end

      it "returns user's stats with default/activity sort" do
        expected_data = build_structure_and_response course_id, authors
        # Sort the map entries using the default sort
        expected_result = expected_data.values.sort_by { |val| [val["threads"], val["responses"], val["replies"], val["username"]] }.reverse

        get "/api/v1/users/#{course_id}/stats"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["user_stats"]).to eq expected_result
      end

      it "handle stats for user with no activity" do
        invalid_course_id = "course-v1:edX+DNE+Not_EXISTS"
        get "/api/v1/users/#{invalid_course_id}/stats"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["user_stats"]).to eq []
      end

      it "returns user's stats filtered by user with default/activity sort" do
        usernames = %w[userauthor-1 userauthor-2 userauthor-3].sample(2)
        usernames = usernames.shuffle.join(',')
        full_data = build_structure_and_response course_id, authors
        # Sort the map entries using the default sort
        expected_result = full_data.values
                                   .select { |val| usernames.include? val["username"] }
                                   .sort_by { |val| usernames.index val["username"] }

        get "/api/v1/users/#{course_id}/stats", usernames: usernames
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["user_stats"]).to eq expected_result
      end

      it "returns user's stats with recency sort" do
        build_structure_and_response course_id, authors
        get "/api/v1/users/#{course_id}/stats", sort_key: "recency", with_timestamps: true
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        sorted_order = res["user_stats"].sort_by { |val| [val["last_activity_at"], val["username"]] }.reverse
        expect(res["user_stats"]).to eq(sorted_order)
      end

      it "returns user's stats with flagged sort" do
        expected_data = build_structure_and_response course_id, authors
        # Sort the map entries using the default sort
        expected_result = expected_data.values.sort_by { |val| [val["active_flags"], val["inactive_flags"], val["username"]] }.reverse

        get "/api/v1/users/#{course_id}/stats", sort_key: "flagged"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["user_stats"]).to eq expected_result
      end

      describe "changes to content" do

        before(:each) do
          expected_data = build_structure_and_response course_id, authors
          get "/api/v1/users/#{course_id}/stats"
          res = parse(last_response.body)
          # Save stats for first entry
          @original_stats = res["user_stats"][0]
          @original_username = @original_stats["username"]
        end

        def get_new_stats
          get "/api/v1/users/#{course_id}/stats"
          res = parse(last_response.body)
          res["user_stats"].detect { |stats| stats["username"] == @original_username }
        end

        it "handles deleting threads" do
          CommentThread.where(:author_username => @original_username, :course_id => course_id).first.destroy
          new_stats = get_new_stats
          # Thread count should have gone down by 1
          expect(new_stats["threads"]).to eq @original_stats["threads"] - 1
          # Replies and responses should have gone down, or stayed the same since all comments and responses in a
          # thread will be deleted.
          expect(new_stats["responses"]).to be <= @original_stats["responses"]
          expect(new_stats["replies"]).to be <= @original_stats["replies"]
        end

        it "handles updating threads" do
          thread = CommentThread.where(:author_username => @original_username, :course_id => course_id).first
          put "/api/v1/threads/#{thread.id}", body: "new body", title: "new title", commentable_id: "new_commentable_id", thread_type: "question", user_id: 1
          expect(last_response).to be_ok
          new_stats = get_new_stats
          # Counts should stay the same
          expect(new_stats["threads"]).to eq @original_stats["threads"]
          expect(new_stats["responses"]).to eq @original_stats["responses"]
          expect(new_stats["replies"]).to eq @original_stats["replies"]
        end

        it "handles adding threads" do
          post "/api/v1/commentable_id/threads",
               title: "new thread",
               body: "new thread",
               course_id: course_id,
               user_id: @original_username.delete_prefix("user")
          expect(last_response).to be_ok
          new_stats = get_new_stats
          # Thread count should stay the same
          expect(new_stats["threads"]).to eq @original_stats["threads"] + 1
          expect(new_stats["responses"]).to eq @original_stats["responses"]
          expect(new_stats["replies"]).to eq @original_stats["replies"]
        end

        it "handles deleting responses" do
          Comment.where(:author_username => @original_username, :course_id => course_id, :parent_id => nil).first.destroy
          new_stats = get_new_stats
          # Thread count should stay the same
          expect(new_stats["threads"]).to eq @original_stats["threads"]
          expect(new_stats["responses"]).to eq @original_stats["responses"] - 1
          expect(new_stats["replies"]).to be <= @original_stats["replies"]
        end

        it "handles updating responses" do
          comment = Comment.where(:author_username => @original_username, :course_id => course_id, :parent_id => nil).first
          put "/api/v1/comments/#{comment.id}", body: "new body", user_id: 1
          expect(last_response).to be_ok
          new_stats = get_new_stats
          # Thread count should stay the same
          expect(new_stats["threads"]).to eq @original_stats["threads"]
          expect(new_stats["responses"]).to eq @original_stats["responses"]
          expect(new_stats["replies"]).to eq @original_stats["replies"]
        end

        it "handles adding responses" do
          thread = CommentThread.where(:author_username => @original_username, :course_id => course_id, :parent_id => nil).first
          post "/api/v1/threads/#{thread.id}/comments", body: "new comment", course_id: course_id, user_id: @original_username.delete_prefix("user")
          expect(last_response).to be_ok
          new_stats = get_new_stats
          # Thread count should stay the same
          expect(new_stats["threads"]).to eq @original_stats["threads"]
          expect(new_stats["responses"]).to eq @original_stats["responses"] + 1
          expect(new_stats["replies"]).to eq @original_stats["replies"]
        end

        it "handles deleting replies" do
          Comment.where(:author_username => @original_username, :course_id => course_id, :parent_id.ne => nil).first.destroy
          new_stats = get_new_stats
          # Thread count should stay the same
          expect(new_stats["threads"]).to eq @original_stats["threads"]
          expect(new_stats["responses"]).to eq @original_stats["responses"]
          expect(new_stats["replies"]).to eq @original_stats["replies"] - 1
        end

        it "handles abuse flags" do
          # Find a comment with no flags
          comment = Comment.where(:author_username => @original_username, :course_id => course_id, :abuse_flaggers => []).first
          # Add a flag
          put "/api/v1/comments/#{comment.id}/abuse_flag", user_id: 1
          new_stats = get_new_stats
          # The active flags should go up.
          expect(new_stats["active_flags"]).to eq @original_stats["active_flags"] + 1
          # All other counts should remain the same
          expect(new_stats["threads"]).to eq @original_stats["threads"]
          expect(new_stats["responses"]).to eq @original_stats["responses"]
          expect(new_stats["replies"]).to eq @original_stats["replies"]
          expect(new_stats["inactive_flags"]).to eq @original_stats["inactive_flags"]
        end

        it "handles removing flags" do
          # Find a comment by this user and set its abuse flaggers to two users.
          comment = Comment.where(:author_username => @original_username, :course_id => course_id, :abuse_flaggers.ne => []).first
          comment.abuse_flaggers = ["1", "2"]
          comment.save

          # Remove the flag by that user
          put "/api/v1/comments/#{comment.id}/abuse_unflag", user_id: 1
          new_stats = get_new_stats
          # The active flags should stay the same right now, since there is still a flagger left.
          expect(new_stats["active_flags"]).to eq @original_stats["active_flags"]

          put "/api/v1/comments/#{comment.id}/abuse_unflag", user_id: 2
          get "/api/v1/users/#{course_id}/stats"
          res = parse(last_response.body)
          new_stats = res["user_stats"].detect { |stats| stats["username"] == @original_username }
          # The active flags should reduce by one, since there are no more flags left.
          expect(new_stats["active_flags"]).to eq @original_stats["active_flags"] - 1
        end
      end
    end

    describe "POST /api/v1/users/:course_id/update_stats" do

      let(:course_id) { Faker::Lorem.word }

      it 'should update user stats when requested' do
        authors = %w[author-1 author-2 author-3 author-4 author-5 author-6].map { |id| create_test_user(id) }
        expected_data = build_structure_and_response course_id, authors, false
        # Sort the map entries using the default sort
        expected_result = expected_data.values.sort_by { |val| [val["threads"], val["responses"], val["replies"]] }.reverse

        get "/api/v1/users/#{course_id}/stats"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["user_stats"]).not_to eq expected_result

        post "/api/v1/users/#{course_id}/update_stats"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["user_count"]).to eq 6

        get "/api/v1/users/#{course_id}/stats"
        expect(last_response.status).to eq(200)
        res = parse(last_response.body)
        expect(res["user_stats"]).to eq expected_result
      end

    end

    describe "POST /api/v1/users/:user_id/read" do

      before(:each) { setup_10_threads }

      it "marks a thread as read for the user" do
        thread = @threads["t0"]
        user = create_test_user(42)
        post "/api/v1/users/#{user.external_id}/read", source_type: "thread", source_id: thread.id
        expect(last_response).to be_ok
        user.reload
        read_states = user.read_states.where(course_id: thread.course_id).to_a
        read_date = read_states.first.last_read_times[thread.id.to_s]
        expect(read_date).to be >= thread.updated_at
      end
    end

    describe "POST /api/v1/users/:user_id/retire" do
      # The Use Retirement code paths are sensitive to the behavior of ES, so
      # we must test with it turned on.
      include_context 'search_enabled'

      describe "with an inactive forums user," do
        before :each do
          User.all.delete
          Content.all.delete
          create_test_user(1)
          # no threads/posts/commentables are set up at all.
        end

        it "retires a user and all the user's data" do
          retired_username = "retired_username_ABCD1234"
          user = User.where(external_id: '1').first
          # User should have original username.
          expect(user.username).to eq('user1')
          # User should not be subscribed to threads.
          get "/api/v1/users/#{user.external_id}/subscribed_threads", course_id: "1"
          expect(last_response).to be_ok
          expect(JSON.parse(last_response.body)['thread_count']).to eq(0)
          get "/api/v1/users/#{user.external_id}/subscribed_threads", course_id: "2"
          expect(last_response).to be_ok
          expect(JSON.parse(last_response.body)['thread_count']).to eq(0)

          # Retire the user.
          post "/api/v1/users/#{user.external_id}/retire", retired_username: retired_username
          expect(last_response).to be_ok

          user.reload
          # User should have retired username.
          expect(user.username).to eq(retired_username)
          # User should have blank email.
          expect(user.email).to eq('')
          # User should be subscribed to no threads.
          get "/api/v1/users/#{user.external_id}/subscribed_threads", course_id: "1"
          expect(last_response).to be_ok
          expect(JSON.parse(last_response.body)['thread_count']).to eq(0)
          get "/api/v1/users/#{user.external_id}/subscribed_threads", course_id: "2"
          expect(last_response).to be_ok
          expect(JSON.parse(last_response.body)['thread_count']).to eq(0)
          # User's comments should be blanked out.
          comments = user.all_comments + user.all_comment_threads
          expect(comments.count).to eq(0)
        end
      end

      describe "with an active forums user," do
        before :each do
          User.all.delete
          Content.all.delete
          init_without_subscriptions
        end

        it "attempts to retire a user without sending retired_username" do
          post "/api/v1/users/1/retire"
          expect(last_response.status).to eq(500)
        end

        it "attempts to retire a user with no subscribed threads" do
          retired_username = "retired_user_test"
          post "/api/v1/users/2/retire", retired_username: retired_username
          expect(last_response).to be_ok
          # User's comments should be blanked out.
          user = User.where(external_id: '2').first
          comments = user.all_comments + user.all_comment_threads
          expect(expect(comments.count)).not_to eq(0)
          comments.each do |single_comment|
            if single_comment._type == 'CommentThread'
              expect(single_comment.title).to match(RETIRED_TITLE)
            end
            expect(single_comment.body).to match(RETIRED_BODY)
            expect(single_comment.author_username).to match(retired_username)
          end
        end

        it "attempts to retire a non-existent user" do
          post "/api/v1/users/1234/retire", retired_username: "retired_user_test"
          expect(last_response.status).to eq(404)
        end

        it "retires the user and all the user's data" do
          retired_username = "retired_username_ABCD1234"
          user = User.where(external_id: '1').first
          # User should have original username.
          expect(user.username).to eq('user1')
          # User should be subscribed to threads.
          get "/api/v1/users/#{user.external_id}/subscribed_threads", course_id: "1"
          expect(last_response).to be_ok
          expect(JSON.parse(last_response.body)['thread_count']).to eq(1)
          get "/api/v1/users/#{user.external_id}/subscribed_threads", course_id: "2"
          expect(last_response).to be_ok
          body = JSON.parse(last_response.body)
          expect(body['thread_count']).to eq(1)
          comment_id = body['collection'][0]['id']

          # Retire the user.
          post "/api/v1/users/#{user.external_id}/retire", retired_username: retired_username
          expect(last_response).to be_ok

          user.reload
          # User should have retired username.
          expect(user.username).to eq(retired_username)
          # User should have blank email.
          expect(user.email).to eq('')
          # User should be subscribed to no threads.
          get "/api/v1/users/#{user.external_id}/subscribed_threads", course_id: "1"
          expect(last_response).to be_ok
          expect(JSON.parse(last_response.body)['thread_count']).to eq(0)
          get "/api/v1/users/#{user.external_id}/subscribed_threads", course_id: "2"
          expect(last_response).to be_ok
          expect(JSON.parse(last_response.body)['thread_count']).to eq(0)
          # User's comments should be blanked out.
          comments = user.all_comments + user.all_comment_threads
          expect(expect(comments.count)).not_to eq(0)
          comments.each do |single_comment|
            if single_comment._type == 'CommentThread'
              expect(single_comment.title).to match(RETIRED_TITLE)
            end
            expect(single_comment.body).to match(RETIRED_BODY)
            expect(single_comment.author_username).to match(retired_username)
          end
        end
      end
    end

    describe "POST /api/v1/users/:user_id/replace_username" do
      include_context 'search_enabled'

      describe "with an inactive forums user," do
        before :each do
          User.all.delete
          Content.all.delete
          create_test_user(1)
          # No user content
        end

        it "replaces a user's username" do
          new_username = "test_username_replacement"
          user = User.where(external_id: '1').first
          # User should have original username.
          expect(user.username).to eq('user1')

          # Replace the username.
          post "/api/v1/users/#{user.external_id}/replace_username", new_username: new_username
          expect(last_response).to be_ok

          user.reload
          # User should have new username.
          expect(user.username).to eq(new_username)
        end
      end

      describe "with an active forums user," do
        before :each do
          User.all.delete
          Content.all.delete
          init_without_subscriptions
        end

        it "attempts to replace username without sending new username" do
          post "/api/v1/users/1/replace_username"
          expect(last_response.status).to eq(500)
        end

        it "attempts to replace username of a non-existant user" do
          new_username = "test_username_replacement"
          post "/api/v1/users/1234/replace_username", new_username: new_username
          expect(last_response.status).to eq(404)
        end

        it "attempts to replace username and username on content" do
          new_username = "test_username_replacement"
          user = User.where(external_id: '1').first
          # User should have original username.
          expect(user.username).to eq('user1')

          # Change the username.
          post "/api/v1/users/#{user.external_id}/replace_username", new_username: new_username
          expect(last_response).to be_ok

          user.reload
          # User should have new username.
          expect(user.username).to eq(new_username)

          # User's comments should all have new username.
          comments = user.all_comments + user.all_comment_threads
          expect(expect(comments.count)).not_to eq(0)
          comments.each do |single_comment|
            expect(single_comment.author_username).to match(new_username)
          end
        end
      end
    end
  end
end
