require 'spec_helper'

describe "app" do
  describe "search" do
    before(:each) { init_without_subscriptions }
    describe "GET /api/v1/search/threads/tags" do
      it "returns all threads tagged with all tags" do
        require 'uri'
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

        post "/api/v1/search/threads/tags", tags: [ai, ml]
        last_response.should be_ok
        threads = parse last_response.body
        threads.length.should == 2
        threads.select{|t| t["id"] == thread1.id.to_s}.first.should_not be_nil
        threads.select{|t| t["id"] == thread2.id.to_s}.first.should_not be_nil

        post "/api/v1/search/threads/tags", tags: [ai]
        last_response.should be_ok
        threads = parse last_response.body
        threads.length.should == 2
        threads.select{|t| t["id"] == thread1.id.to_s}.first.should_not be_nil
        threads.select{|t| t["id"] == thread2.id.to_s}.first.should_not be_nil

        post "/api/v1/search/threads/tags", tags: [ai, random1]
        last_response.should be_ok
        threads = parse last_response.body
        threads.length.should == 1
        threads.select{|t| t["id"] == thread1.id.to_s}.first.should_not be_nil

        post "/api/v1/search/threads/tags", tags: [random1]
        last_response.should be_ok
        threads = parse last_response.body
        threads.length.should == 1
        threads.select{|t| t["id"] == thread1.id.to_s}.first.should_not be_nil

        post "/api/v1/search/threads/tags", tags: [random1, random2]
        last_response.should be_ok
        threads = parse last_response.body
        threads.length.should == 0
      end
    end
  end
end
