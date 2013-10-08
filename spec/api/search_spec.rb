require 'spec_helper'

describe "app" do
  describe "search" do
    before(:each) { init_without_subscriptions }
    describe "GET /api/v1/search/threads" do
      it "returns all threads tagged with all tags" do
        thread1 = CommentThread.all.to_a.first
        thread2 = CommentThread.all.to_a.last
        ai = "artificial intelligence"
        ml = "marchine learning"
        random1 = "random1"
        random2 = "random2"
        random3 = "random3"
        thread1.tags = [ai, ml, random1].join ","
        thread1.save
        thread2.tags = [ai, ml, random2].join ","
        thread2.save

        sleep 1

        get "/api/v1/search/threads", tags: [ai, ml].join(",")
        last_response.should be_ok
        threads = parse(last_response.body)['collection']
        threads.length.should == 2
        check_thread_result(nil, thread1, threads.select{|t| t["id"] == thread1.id.to_s}.first, false, true)
        check_thread_result(nil, thread2, threads.select{|t| t["id"] == thread2.id.to_s}.first, false, true)

        get "/api/v1/search/threads", tags: [ai].join(",")
        last_response.should be_ok
        threads = parse(last_response.body)['collection']
        threads.length.should == 2
        check_thread_result(nil, thread1, threads.select{|t| t["id"] == thread1.id.to_s}.first, false, true)
        check_thread_result(nil, thread2, threads.select{|t| t["id"] == thread2.id.to_s}.first, false, true)

        get "/api/v1/search/threads", tags: [ai, random1].join(",")
        last_response.should be_ok
        threads = parse(last_response.body)['collection']
        threads.length.should == 1
        check_thread_result(nil, thread1, threads.select{|t| t["id"] == thread1.id.to_s}.first, false, true)

        get "/api/v1/search/threads", tags: [random1].join(",")
        last_response.should be_ok
        threads = parse(last_response.body)['collection']
        threads.length.should == 1
        check_thread_result(nil, thread1, threads.select{|t| t["id"] == thread1.id.to_s}.first, false, true)

        get "/api/v1/search/threads", tags: [random1, random2].join(",")
        last_response.should be_ok
        threads = parse(last_response.body)['collection']
        threads.length.should == 0
      end
    end
  end
end
