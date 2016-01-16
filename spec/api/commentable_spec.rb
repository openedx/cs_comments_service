require 'spec_helper'
require 'unicode_shared_examples'

describe 'app' do
  describe 'commentables' do
    before(:each) { set_api_key_header }
    let(:commentable_id) { Faker::Lorem.word }

    describe 'DELETE /api/v1/:commentable_id/threads' do
      it 'delete all associated threads and comments of a commentable' do
        thread_count = 2
        create_list(:comment_thread, thread_count, commentable_id: commentable_id)
        expect(Commentable.find(commentable_id).comment_threads.count).to eq thread_count

        delete "/api/v1/#{commentable_id}/threads"
        expect(last_response).to be_ok
        expect(Commentable.find(commentable_id).comment_threads.count).to eq 0
      end

      context 'if the commentable does not exist' do
        subject { delete '/api/v1/does_not_exist/threads' }

        it { should be_ok }
      end
    end

    describe 'GET /api/v1/:commentable_id/threads' do
      let(:returned_threads) { parse(subject.body)['collection'] }
      subject { get "/api/v1/#{commentable_id}/threads" }

      shared_examples_for 'a filterable API endpoint' do
        let!(:ignored_threads) { create_list(:comment_thread, 3, commentable_id: commentable_id) }
        subject { get "/api/v1/#{commentable_id}/threads", parameters }

        it { should be_ok }

        it 'returns the correct CommentThreads' do
          expect(returned_threads.length).to eq threads.length
          threads.sort_by!(&:_id).reverse!
          threads.each_with_index do |thread, index|
            expect(returned_threads[index]).to include('id' => thread.id.to_s, 'body' => thread.body)
          end
        end
      end

      context 'without filtering' do
        let(:parameters) { {} }
        let!(:threads) { ignored_threads + create_list(:comment_thread, 3, :with_group_id, commentable_id: commentable_id) }

        it_behaves_like 'a filterable API endpoint'
      end

      context 'when filtering by the standalone context' do
        let(:parameters) { {context: :standalone} }
        let!(:threads) { create_list(:comment_thread, 3, commentable_id: commentable_id, context: :standalone) }

        it_behaves_like 'a filterable API endpoint'
      end

      context 'when filtering by course_id' do
        let(:course_id) { Faker::Lorem.word }
        let(:parameters) { {course_id: course_id} }
        let!(:threads) { create_list(:comment_thread, 3, commentable_id: commentable_id, course_id: course_id) }


        it_behaves_like 'a filterable API endpoint'
      end

      context 'when filtering by group_id' do
        let(:group_id) { Faker::Number.number(4) }
        let(:parameters) { {group_id: group_id} }
        let!(:threads) { create_list(:comment_thread, 3, commentable_id: commentable_id, group_id: group_id) }


        it_behaves_like 'a filterable API endpoint'
      end

      context 'when filtering by multiple group_id values' do
        let(:group_ids) { [Faker::Number.number(4), Faker::Number.number(4)] }
        let(:parameters) { {group_ids: group_ids.join(',')} }


        it_behaves_like 'a filterable API endpoint' do
          let!(:threads) do
            threads = []

            group_ids.each do |group_id|
              threads += create_list(:comment_thread, 3, commentable_id: commentable_id, group_id: group_id)
            end

            threads
          end
        end
      end

      context 'when the commentable does not exist' do
        subject { get '/api/v1/does_not_exist/threads' }

        it { should be_ok }

        it 'should not return any results' do
          expect(returned_threads.length).to eq 0
        end
      end

      def test_unicode_data(text)
        commentable_id = 'unicode_commentable'
        thread = create(:comment_thread, commentable_id: commentable_id, body: text)
        create(:comment, comment_thread: thread, body: text)

        get "/api/v1/#{commentable_id}/threads"
        last_response.should be_ok
        result = parse(last_response.body)['collection']
        result.should_not be_empty
        check_thread_result_json(nil, thread, result.first)
      end

      include_examples 'unicode data'
    end

    describe 'POST /api/v1/:commentable_id/threads' do
      let(:commentable_id) { Faker::Lorem.word }
      let(:user) { create(:user) }
      let(:parameters) { attributes_for(:comment_thread, user_id: user.id) }
      subject { post "/api/v1/#{commentable_id}/threads", parameters }

      shared_examples_for 'CommentThread creation API' do |context='course'|
        it 'creates a new CommentThread' do
          expect(CommentThread.count).to eq 0

          body = parse(subject.body)
          expect(body).to include('read' => false,
                                  'unread_comments_count' => 0,
                                  'endorsed' => false,
                                  'resp_total' => 0)

          expect(CommentThread.count).to eq 1

          thread = CommentThread.find(body['id'])
          expect(thread).to_not be_nil
          expect(thread.context).to eq context
        end
      end

      it { should be_ok }

      it_behaves_like 'CommentThread creation API'
      it_behaves_like 'CommentThread creation API', 'standalone' do
        let(:parameters) { attributes_for(:comment_thread, user_id: user.id, context: 'standalone') }
      end

      CommentThread.thread_type.values.each do |thread_type|
        it "can create a #{thread_type} thread" do
          old_count = CommentThread.where(thread_type: thread_type).count
          post '/api/v1/question_1/threads', parameters.merge(thread_type: thread_type.to_s)
          last_response.should be_ok
          parse(last_response.body)['thread_type'].should == thread_type.to_s
          CommentThread.where(thread_type: thread_type).count.should == old_count + 1
        end
      end

      it 'allows anonymous thread' do
        post '/api/v1/question_1/threads', parameters.merge!(anonymous: true)
        last_response.should be_ok
        body = parse(subject.body)

        thread = CommentThread.find(body['id'])
        expect(thread).to_not be_nil
        expect(thread['anonymous']).to be_true
      end

      it 'returns error when title, body or course id does not exist' do
        [:title, :body, :course_id].each do |parameter|
          params = parameters.dup
          params.delete(parameter)
          post '/api/v1/question_1/threads', params
          last_response.status.should == 400
        end
      end

      it "returns error when title or body is blank (only consists of spaces and new lines)" do
        post '/api/v1/question_1/threads', parameters.merge(title: "     ")
        last_response.status.should == 400
        post '/api/v1/question_1/threads', parameters.merge(body: "     \n    \n")
        last_response.status.should == 400
      end

      it 'returns 503 and does not create when the post content is blocked' do
        body = 'BLOCKED POST'
        hash = block_post_body
        post '/api/v1/question_1/threads', parameters.merge!(body: body)
        last_response.status.should == 503
        parse(last_response.body).first.should == I18n.t(:blocked_content_with_body_hash, :hash => hash)
        expect(CommentThread.where(body: body).length).to eq 0
      end

      def test_unicode_data(text)
        commentable_id = 'unicode_commentable'
        post "/api/v1/#{commentable_id}/threads", parameters.merge!(body: text, title: text)
        last_response.should be_ok
        expect(CommentThread.where(commentable_id: commentable_id, body: text, title: text)).to_not be_empty
      end

      include_examples 'unicode data'
    end
  end
end
