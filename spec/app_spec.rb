require 'spec_helper'

describe "app" do

  describe "access control" do
    let(:user) { create_test_user(42) }
    # all routes (even nonexistent ones) are covered by the api key
    # /heartbeat is the only exception, covered in the heartbeat tests below
    let(:urls) { {
        "/" => 404,
        "/api/v1/users/#{user.id}" => 200,
        "/api/v1/users/doesnotexist" => 404,
        "/selftest" => 200
      }
    }

    it "returns 401 when api key header is unset" do
      urls.each do |url, _|
        get url
        last_response.status.should == 401
      end
    end

    it "returns 401 when api key value is incorrect" do
      urls.each do |url, _|
        get url, {}, {"HTTP_X_EDX_API_KEY" => "incorrect-#{TEST_API_KEY}"}
        last_response.status.should == 401
      end
    end

    it "allows requests when api key value is correct" do
      urls.each do |url, status|
        get url, {}, {"HTTP_X_EDX_API_KEY" => TEST_API_KEY}
        last_response.status.should == status
      end
    end
  end

  describe "heartbeat monitoring" do
    it "does not require api key" do
      get "/heartbeat"
      last_response.status.should == 200
    end

    context "db check" do
      def test_db_check(response, is_success)
        db = double("db")
        stub_const("Mongoid::Clients", Class.new).stub(:default).and_return(db)
        result = double('result')
        result.stub(:ok?).and_return(response['ok'] == 1)
        result.stub(:documents).and_return([response])
        db.should_receive(:command).with({:isMaster => 1}).and_return(result)
        get "/heartbeat"
        if is_success
          last_response.status.should == 200
          parse(last_response.body).should == {"OK" => true}
        else
          last_response.status.should == 500
          parse(last_response.body).should == {"OK" => false, "check" => "db"}
        end
      end

      it "reports success when mongo is ready" do
        test_db_check({"ismaster" => true, "ok" => 1}, true)
      end

      it "reports failure when mongo is not master" do
        test_db_check({"ismaster" => false, "ok" => 1}, false)
      end

      it "reports failure when mongo is not OK" do
        test_db_check({"ismaster" => true, "ok" => 0}, false)
      end

      it "reports failure when command response is unexpected" do
        test_db_check({"foo" => "bar"}, false)
      end

      it "reports failure when db command raises an error" do
        db = double("db")
        stub_const("Mongoid::Clients", Class.new).stub(:default).and_return(db)
        db.should_receive(:command).with({:isMaster => 1}).and_raise(StandardError)
        get "/heartbeat"
        last_response.status.should == 500
        parse(last_response.body).should == {"OK" => false, "check" => "db"}
      end
    end

    context "elasticsearch check" do
      def test_es_check(response, is_success)
        # fake HTTP call
        client = double()
        tire_config = stub_const("Tire::Configuration", Class.new)
        tire_config.stub(:url).and_return("foo")
        tire_config.stub(:client).and_return(client)
        # fake HTTP response based on our response parameter
        es_response = double()
        es_response.stub(:body).and_return(JSON.generate(response))
        client.should_receive(:get).and_return(es_response)

        get "/heartbeat"
        if is_success
          last_response.status.should == 200
          parse(last_response.body).should == {"OK" => true}
        else
          last_response.status.should == 500
          parse(last_response.body).should == {"OK" => false, "check" => "es"}
        end
      end

      it "reports success when es is ready" do
        test_es_check({"status" => 200}, true)
      end

      it "reports failure when es status is unexpected" do
        test_es_check({"status" => 503}, false)
      end

      it "reports failure when es status is malformed" do
        test_es_check("", false)
      end

      it "reports failure when the es command raises an error" do
        client = double()
        tire_config = stub_const("Tire::Configuration", Class.new)
        tire_config.stub(:url).and_return("foo")
        tire_config.stub(:client).and_raise(StandardError)
        get "/heartbeat"
        last_response.status.should == 500
        parse(last_response.body).should == {"OK" => false, "check" => "es"}
      end
    end
  end

  describe "selftest" do

    it "returns valid JSON on success" do
      get "/selftest", {}, {"HTTP_X_EDX_API_KEY" => TEST_API_KEY}
      res = parse(last_response.body)
      %w(db es total_posts total_users last_post_created elapsed_time).each do |k|
        res.should have_key k
      end
    end

    it "handles when the database is empty" do
      get "/selftest", {}, {"HTTP_X_EDX_API_KEY" => TEST_API_KEY}
      res = parse(last_response.body)
      res["total_users"].should == 0
      res["total_posts"].should == 0
      res["last_post_created"].should == nil
    end

    it "handles when the database is not empty" do
      user = create_test_user(42)
      thread = make_thread(user, "foo", "abc", "123")
      get "/selftest", {}, {"HTTP_X_EDX_API_KEY" => TEST_API_KEY}
      res = parse(last_response.body)
      res["total_users"].should == 1
      res["total_posts"].should == 1
      Time.parse(res["last_post_created"]).to_i.should == thread.created_at.to_i
    end

    it "displays tracebacks on failure" do
      Tire::Configuration.client.should_receive(:get).and_raise(StandardError)
      get "/selftest", {}, {"HTTP_X_EDX_API_KEY" => TEST_API_KEY}
      last_response.status.should == 500
      # lightweight assertion that we're seeing a traceback
      last_response.headers["Content-Type"].should == 'text/plain'
      last_response.body.should include "StandardError"
      last_response.body.should include File.expand_path(__FILE__)
    end

  end
end
