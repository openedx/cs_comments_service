require 'spec_helper'

describe 'app' do
  describe 'access control' do
    let(:user) { create_test_user(42) }
    # all routes (even nonexistent ones) are covered by the api key
    # /heartbeat is the only exception, covered in the heartbeat tests below
    let(:urls) do
      {
          "/" => 404,
          "/api/v1/users/#{user.id}" => 200,
          "/api/v1/users/doesnotexist" => 404,
          "/selftest" => 200
      }
    end

    it 'returns 401 when api key header is not set' do
      urls.keys.each do |url|
        get url
        expect(last_response.status).to eq 401
      end
    end

    it 'returns 401 when api key value is incorrect' do
      urls.keys.each do |url|
        get url, {}, {'HTTP_X_EDX_API_KEY' => "incorrect-#{TEST_API_KEY}"}
        expect(last_response.status).to eq 401
      end
    end

    it 'allows requests when api key value is correct' do
      urls.each do |url, status|
        get url, {}, {'HTTP_X_EDX_API_KEY' => TEST_API_KEY}
        expect(last_response.status).to eq status
      end
    end
  end

  describe 'heartbeat monitoring' do
    subject do
      get '/heartbeat'
      last_response
    end

    it 'does not require api key' do
      expect(subject.status).to eq 200
    end

    context 'db check' do
      def test_db_check(response, is_success)
        db = double("db")
        stub_const('Mongoid::Clients', Class.new).stub(:default).and_return(db)
        result = double('result')
        result.stub(:ok?).and_return(response['ok'] == 1)
        result.stub(:documents).and_return([response])
        db.stub(:close).and_return(true)
        db.stub(:reconnect).and_return(true)
        db.stub(:options).and_return({read: {mode: :primary}})
        # should be checked twice, because it will retry
        db.should_receive(:command).with({:isMaster => 1}).twice.and_return(result)

        body = parse(subject.body)
        if is_success
          expect(subject.status).to eq 200
          expect(body).to eq({'OK' => true})
        else
          expect(subject.status).to eq 500
          expect(body).to eq({'OK' => false, 'check' => 'db'})
        end
      end

      it 'reports success when mongo is ready' do
        test_db_check({'ismaster' => true, 'ok' => 1}, true)
      end

      it 'reports failure when mongo is not master' do
        test_db_check({'ismaster' => false, 'ok' => 1}, false)
      end

      it 'reports failure when mongo is not OK' do
        test_db_check({'ismaster' => true, 'ok' => 0}, false)
      end

      it 'reports failure when command response is unexpected' do
        test_db_check({'foo' => 'bar'}, false)
      end

      it 'reports failure when db command raises an error' do
        db = double('db')
        stub_const('Mongoid::Clients', Class.new).stub(:default).and_return(db)
        db.stub(:close).and_return(true)
        db.stub(:reconnect).and_return(true)
        # should be checked twice, because it will retry
        db.should_receive(:command).with({:isMaster => 1}).twice.and_raise(StandardError)

        expect(subject.status).to eq 500
        expect(parse(subject.body)).to eq({'OK' => false, 'check' => 'db'})
      end
    end

    context 'elasticsearch check' do
      after(:each) { WebMock.reset! }

      def test_es_check(service_available, status='green', timed_out=false)
        body = {
            status: status,
            timed_out: timed_out,
        }
        url = "#{CommentService.config[:elasticsearch_server]}/_cluster/health"
        stub = stub_request(:any, url).to_return(body: body.to_json, headers: {'Content-Type' => 'application/json'})

        body = parse(subject.body)
        expect(stub).to have_been_requested

        if service_available
          expect(last_response.status).to eq 200
          expect(body).to eq({'OK' => true})
        else
          expect(last_response.status).to eq 500
          expect(body).to eq({'OK' => false, 'check' => 'es'})
        end
      end

      it 'reports success if cluster status is green' do
        test_es_check(true, 'green')
      end

      it 'reports success if cluster status is yellow' do
        test_es_check(true, 'yellow')
      end

      it 'reports failure if cluster status is red' do
        test_es_check(false, 'red')
      end

      it 'reports failure if cluster status is unexpected' do
        test_es_check(false, 'unexpected')
      end

      it 'reports failure if the cluster health check times out' do
        test_es_check(false, 'green', true)
      end
    end
  end

  describe 'selftest' do
    subject do
      get '/selftest', {}, {'HTTP_X_EDX_API_KEY' => TEST_API_KEY}
      parse(last_response.body)
    end

    it 'returns valid JSON on success' do
      expect(subject).to include('db', 'es', 'total_posts', 'total_users', 'last_post_created', 'elapsed_time')
    end

    it 'handles when the database is empty' do
      expect(subject).to include('total_users' => 0,
                                 'total_posts' => 0,
                                 'last_post_created' => nil)
    end

    it 'handles when the database is not empty' do
      thread = create(:comment_thread)
      expect(subject).to include(
                             'total_users' => 1,
                             'total_posts' => 1,
                             'last_post_created' => thread.created_at.utc.iso8601)
    end

    it "displays tracebacks on failure" do
      url = "#{CommentService.config[:elasticsearch_server]}/_cluster/health"
      stub = stub_request(:any, url).to_raise(StandardError)

      get '/selftest', {}, {'HTTP_X_EDX_API_KEY' => TEST_API_KEY}
      expect(stub).to have_been_requested
      WebMock.reset!

      expect(last_response.status).to eq 500
      expect(last_response.headers).to include('Content-Type' => 'text/plain')
      expect(last_response.body).to include 'StandardError'
      expect(last_response.body).to include File.expand_path(__FILE__)
    end
  end

  describe 'config' do
    describe 'Elasticsearch client' do
      subject { Elasticsearch::Model.client }

      it 'has a host value set to that from application.yaml' do
        expected = URI::parse(CommentService.config[:elasticsearch_server])
        host = subject.transport.hosts[0]
        host[:port] = host[:port].to_i
        expect(URI::HTTP.build(host)).to eq expected
      end
    end
  end
end
