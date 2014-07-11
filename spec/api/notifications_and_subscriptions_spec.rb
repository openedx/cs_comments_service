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
        last_response.should be_ok
        parse(last_response.body)["collection"]
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
          @comments["t2 c3"].abuse_flaggers = [1] # note: not subscribed
          @comments["t2 c3"].save!
          @comments["t3 c3"].abuse_flaggers = [1] # subscribed
          @comments["t3 c3"].save!
          rs = thread_result course_id: DFLT_COURSE_ID, flagged: true
          rs.length.should == 1
          check_thread_result_json(nil, @threads["t3"], rs.first)
        end
        it "returns an empty result when no posts were flagged" do
          rs = thread_result course_id: DFLT_COURSE_ID, flagged: true
          rs.length.should == 0 
        end
      end
      it "filters by group_id" do
        rs = thread_result course_id: DFLT_COURSE_ID, group_id: 42
        rs.length.should == 5
        @threads["t3"].group_id = 43
        @threads["t3"].save!
        rs = thread_result course_id: DFLT_COURSE_ID, group_id: 42
        rs.length.should == 4
        @threads["t3"].group_id = 42
        @threads["t3"].save!
        rs = thread_result course_id: DFLT_COURSE_ID, group_id: 42
        rs.length.should == 5
      end
      it "filters by group_ids" do
        rs = thread_result course_id: DFLT_COURSE_ID, group_ids: "42"
        rs.length.should == 5
        @threads["t3"].group_id = 43
        @threads["t3"].save!
        rs = thread_result course_id: DFLT_COURSE_ID, group_ids: "42"
        rs.length.should == 4
        rs = thread_result course_id: DFLT_COURSE_ID, group_ids: "42,43"
        rs.length.should == 5
      end
      it "filters unread posts" do
        rs = thread_result course_id: DFLT_COURSE_ID
        rs.length.should == 5
        rs2 = thread_result course_id: DFLT_COURSE_ID, unread: true
        rs2.should == rs
        subscriber.mark_as_read(@threads[rs.first["title"]])
        rs3 = thread_result course_id: DFLT_COURSE_ID, unread: true
        rs3.should == rs[1..4]
        rs[1..3].each { |r| subscriber.mark_as_read(@threads[r["title"]]) }
        rs4 = thread_result course_id: DFLT_COURSE_ID, unread: true
        rs4.should == rs[4, 1]
        subscriber.mark_as_read(@threads[rs.last["title"]])
        rs5 = thread_result course_id: DFLT_COURSE_ID, unread: true
        rs5.should == []
        make_comment(create_test_user(Random.new), @threads[rs.first["title"]], "new activity")
        rs6 = thread_result course_id: DFLT_COURSE_ID, unread: true
        rs6.length.should == 1
        rs6.first["title"].should == rs.first["title"]
      end
      it "filters unanswered questions" do
        %w[t9 t7].each do |thread_key|
          @threads[thread_key].thread_type = :question
          @threads[thread_key].save!
        end
        rs = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        rs.length.should == 2
        @comments["t7 c0"].endorsed = true
        @comments["t7 c0"].save!
        rs2 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        rs2.length.should == 1
        @comments["t9 c0"].endorsed = true
        @comments["t9 c0"].save!
        rs3 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        rs3.length.should == 0
      end
      it "ignores endorsed comments that are not question responses" do
        thread = @threads["t1"]
        thread.thread_type = :question
        thread.save!
        rs = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        rs.length.should == 1
        comment = make_comment(create_test_user(Random.new), thread.comments.first, "comment on a response")
        comment.endorsed = true
        comment.save!
        rs2 = thread_result course_id: DFLT_COURSE_ID, unanswered: true
        rs2.length.should == 1
      end
    end

    describe "POST /api/v1/users/:user_id/subscriptions" do
      it "subscribe a comment thread" do
        thread = @threads["t0"]
        post "/api/v1/users/#{subscriber.external_id}/subscriptions", source_type: "thread", source_id: thread.id
        last_response.should be_ok
        thread.subscribers.length.should == 1
        thread.subscribers[0].should == subscriber
      end
    end

    describe "DELETE /api/v1/users/:user_id/subscriptions" do
      it "unsubscribe a comment thread" do
        thread = @threads["t2"]
        subscriber.subscribe(thread)
        thread.subscribers.length.should == 1
        thread.subscribers[0].should == subscriber
        delete "/api/v1/users/#{subscriber.external_id}/subscriptions", source_type: "thread", source_id: thread.id
        last_response.should be_ok
        thread.subscribers.length.should == 0
      end
    end

  end
end
