require 'spec_helper'

describe 'Abuse API' do
  before(:each) { set_api_key_header }

  shared_examples 'an abuse endpoint' do
    let(:affected_entity_id) { affected_entity.id }
    let(:user_id) { create(:user).id }

    it { should be_ok }

    it 'updates the abuse flaggers' do
      subject

      affected_entity.reload
      expect(affected_entity.abuse_flaggers).to eq expected_abuse_flaggers
      expect(non_affected_entity.abuse_flaggers).to have(0).items
    end

    context 'if the comment does not exist' do
      let(:affected_entity_id) { 'does_not_exist' }
      it { should be_bad_request }
      its(:body) { should eq "[\"#{I18n.t(:requested_object_not_found)}\"]" }
    end

    context 'if no user_id is provided' do
      let(:user_id) { nil }
      it { should be_bad_request }
      its(:body) { should eq "[\"#{I18n.t(:user_id_is_required)}\"]" }
    end
  end

  describe 'comment actions' do
    let(:affected_entity) { create(:comment, abuse_flaggers: []) }
    let(:non_affected_entity) { affected_entity.comment_thread }

    context 'when flagging a comment for abuse' do
      let(:expected_abuse_flaggers) { [user_id] }
      subject { put "/api/v1/comments/#{affected_entity_id}/abuse_flag", user_id: user_id }

      it_behaves_like 'an abuse endpoint'
    end

    context 'when un-flagging a comment for abuse' do
      let(:affected_entity) { create(:comment, abuse_flaggers: [user_id]) }
      let(:expected_abuse_flaggers) { [] }
      subject { put "/api/v1/comments/#{affected_entity_id}/abuse_unflag", user_id: user_id }

      it_behaves_like 'an abuse endpoint'
    end
  end

  describe 'comment thread actions' do
    let(:affected_entity) { create(:comment_thread, abuse_flaggers: []) }
    let(:non_affected_entity) { create(:comment, comment_thread: affected_entity) }

    context 'when flagging a comment thread for abuse' do
      let(:expected_abuse_flaggers) { [user_id] }
      subject { put "/api/v1/threads/#{affected_entity_id}/abuse_flag", user_id: user_id }

      it_behaves_like 'an abuse endpoint'
    end

    context 'when un-flagging a comment thread for abuse' do
      let(:affected_entity) { create(:comment_thread, abuse_flaggers: [user_id]) }
      let(:expected_abuse_flaggers) { [] }
      subject { put "/api/v1/threads/#{affected_entity_id}/abuse_unflag", user_id: user_id }

      it_behaves_like 'an abuse endpoint'
    end
  end
end
