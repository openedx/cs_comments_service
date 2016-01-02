require 'spec_helper'
require 'faker'


describe 'app' do
  before(:each) { set_api_key_header }
  let(:body) { Faker::Lorem.word }

  describe 'GET /api/v1/search/threads' do

    shared_examples_for 'a search endpoint' do
      subject do
        refresh_es_index
        get '/api/v1/search/threads', text: body
      end

      let(:matched_thread) { parse(subject.body)['collection'].select { |t| t['id'] == thread.id.to_s }.first }

      it { should be_ok }

      it 'returns thread with query match' do
        expect(matched_thread).to_not be_nil
        check_thread_result_json(nil, thread, matched_thread)
      end
    end

    context 'when searching on thread content' do
      let!(:thread) { create(:comment_thread, body: body) }

      it_behaves_like 'a search endpoint'
    end

    context 'when searching on comment content' do
      let!(:thread) do
        comment = create(:comment, body: body)
        thread = comment.comment_thread
      end

      it_behaves_like 'a search endpoint'
    end
  end
end
