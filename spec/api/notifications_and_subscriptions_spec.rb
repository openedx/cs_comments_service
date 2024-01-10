require 'spec_helper'

describe "app" do
  describe "notifications and subscriptions" do

    let(:subscriber) { create_test_user(42) }

    before(:each) do
      set_api_key_header
      setup_10_threads
      %w[t9 t7 t5 t3 t1].each { |t| subscriber.subscribe(@threads[t]) }
    end

    describe "GET /api/v1/users/:user_id/subscribed_threads" do

      def thread_result(params)
        get "/api/v1/users/#{subscriber.id}/subscribed_threads", params
        expect(last_response).to be_ok
        parse(last_response.body)["collection"]
      end

      context "when filtering flagged posts" do
        it "returns threads that are flagged" do
          @threads["t1"].abuse_flaggers = [1]
          @threads["t1"].save!
          rs = thread_result course_id: DFLT_COURSE_ID, flagged: true
          expect(rs.length).to eq(1)
          check_thread_result_json(nil, @threads["t1"], rs.first)
        end
        it "returns threads that have flagged comments" do
          @comments["t2 c3"].abuse_flaggers = [1] # note: not subscribed
          @comments["t2 c3"].save!
          @comments["t3 c3"].abuse_flaggers = [1] # subscribed
          @comments["t3 c3"].save!
          rs = thread_result course_id: DFLT_COURSE_ID, flagged: true
          expect(rs.length).to eq(1)
          check_thread_result_json(nil, @threads["t3"], rs.first)
        end
        it "returns an empty result when no posts were flagged" do
          rs = thread_result course_id: DFLT_COURSE_ID, flagged: true
          expect(rs.length).to eq(0)
        end
      end
      it "filters by group_id" do
        rs = thread_result course_id: DFLT_COURSE_ID, group_id: 42
        expect(rs.length).to eq(5)
        @threads["t3"].group_id = 43
        @threads["t3"].save!
        rs = thread_result course_id: DFLT_COURSE_ID, group_id: 42
        expect(rs.length).to eq(4)
        @threads["t3"].group_id = 42
        @threads["t3"].save!
        rs = thread_result course_id: DFLT_COURSE_ID, group_id: 42
        expect(rs.length).to eq(5)
      end
      it "filters by group_ids" do
        rs = thread_result course_id: DFLT_COURSE_ID, group_ids: "42"
        expect(rs.length).to eq(5)
        @threads["t3"].group_id = 43
        @threads["t3"].save!
        rs = thread_result course_id: DFLT_COURSE_ID, group_ids: "42"
        expect(rs.length).to eq(4)
        rs = thread_result course_id: DFLT_COURSE_ID, group_ids: "42,43"
        expect(rs.length).to eq(5)
      end
      it "filters unread posts" do
        rs = thread_result course_id: DFLT_COURSE_ID
        expect(rs.length).to eq(5)
        rs2 = thread_result course_id: DFLT_COURSE_ID, unread: true
        expect(rs2).to eq(rs)
        subscriber.mark_as_read(@threads[rs.first["title"]])
        rs3 = thread_result course_id: DFLT_COURSE_ID, unread: true
        expect(rs3).to eq(rs[1..4])
        rs[1..3].each { |r| subscriber.mark_as_read(@threads[r["title"]]) }
        rs4 = thread_result course_id: DFLT_COURSE_ID, unread: true
        expect(rs4).to eq(rs[4, 1])
        subscriber.mark_as_read(@threads[rs.last["title"]])
        rs5 = thread_result course_id: DFLT_COURSE_ID, unread: true
        expect(rs5).to eq([])
        make_comment(create_test_user(Random.new), @threads[rs.first["title"]], "new activity")
        rs6 = thread_result course_id: DFLT_COURSE_ID, unread: true
        expect(rs6.length).to eq(1)
        expect(rs6.first["title"]).to eq(rs.first["title"])
      end
      it "filters unanswered questions" do
        %w[t9 t7].each do |thread_key|
          @threads[thread_key].thread_type = :question
          @threads[thread_key].save!
        end
        rs = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        expect(rs.length).to eq(2)
        @comments["t7 c0"].endorsed = true
        @comments["t7 c0"].save!
        rs2 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        expect(rs2.length).to eq(1)
        @comments["t9 c0"].endorsed = true
        @comments["t9 c0"].save!
        rs3 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        expect(rs3.length).to eq(0)
      end
      it "ignores endorsed comments that are not question responses" do
        thread = @threads["t1"]
        thread.thread_type = :question
        thread.save!
        rs = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        expect(rs.length).to eq(1)
        comment = make_comment(create_test_user(Random.new), thread.comments.first, "comment on a response")
        comment.endorsed = true
        comment.save!
        rs2 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        expect(rs2.length).to eq(1)
      end
    end

    describe "POST /api/v1/users/:user_id/subscriptions" do
      it "subscribe a comment thread" do
        thread = @threads["t0"]
        post "/api/v1/users/#{subscriber.external_id}/subscriptions", source_type: "thread", source_id: thread.id
        expect(last_response).to be_ok
        expect(thread.subscribers.length).to eq(1)
        expect(thread.subscribers[0]).to eq(subscriber)
      end
    end

    describe "DELETE /api/v1/users/:user_id/subscriptions" do
      it "unsubscribe a comment thread" do
        thread = @threads["t2"]
        subscriber.subscribe(thread)
        expect(thread.subscribers.length).to eq(1)
        expect(thread.subscribers[0]).to eq(subscriber)
        delete "/api/v1/users/#{subscriber.external_id}/subscriptions", source_type: "thread", source_id: thread.id
        expect(last_response).to be_ok
        expect(thread.subscribers.length).to eq(0)
      end
    end
    describe "GET /api/v1/threads/:thread_id/subscriptions" do
      it "Get subscribers of thread" do
        thread = @threads["t2"]
        subscriber.subscribe(thread)
        expect(thread.subscribers.length).to eq(1)

        get "/api/v1/threads/#{thread.id}/subscriptions", { 'page': 1 }
        expect(last_response).to be_ok
        response = parse(last_response.body)
        expect(response['collection'].length).to eq(1)
        expect(response['num_pages']).to eq(1)
        expect(response['page']).to eq(1)
        expect(response['subscriptions_count']).to eq(1)
        puts last_response.body

      end
    end

    describe "GET /api/v1/threads/:thread_id/subscriptions" do
      it "Get subscribers of thread with pagination" do
        thread = @threads["t2"]

        subscriber.subscribe(thread)
        create_test_user(43).subscribe(thread)
        create_test_user(44).subscribe(thread)
        create_test_user(45).subscribe(thread)
        create_test_user(46).subscribe(thread)
        create_test_user(47).subscribe(thread)

        expect(thread.subscribers.length).to eq(6)

        get "/api/v1/threads/#{thread.id}/subscriptions", { 'page': 1, 'per_page': 2 }
        expect(last_response).to be_ok
        response = parse(last_response.body)
        expect(response['collection'].length).to eq(2)
        expect(response['num_pages']).to eq(3)
        expect(response['page']).to eq(1)
        expect(response['subscriptions_count']).to eq(6)

        get "/api/v1/threads/#{thread.id}/subscriptions", { 'page': 2, 'per_page': 2 }
        expect(last_response).to be_ok
        response = parse(last_response.body)
        expect(response['collection'].length).to eq(2)
        expect(response['num_pages']).to eq(3)
        expect(response['page']).to eq(2)
        expect(response['subscriptions_count']).to eq(6)
      end
    end

  end
end
