require 'spec_helper'
require 'unicode_shared_examples'

BLOCKED_BODY = 'BLOCKED POST'

describe 'Comment API' do
  before(:each) { set_api_key_header }
  let(:thread) { create_comment_thread_and_comments }

  describe 'GET /api/v1/comments/:comment_id' do
    it 'returns JSON' do
      comment = thread.comments.first
      get "/api/v1/comments/#{comment.id}"
      last_response.should be_ok
      last_response.content_type.should == 'application/json;charset=utf-8'
    end

    it 'retrieve information of a single comment' do
      comment = thread.comments.first
      get "/api/v1/comments/#{comment.id}"
      last_response.should be_ok
      retrieved = parse last_response.body
      retrieved['body'].should == comment.body
      retrieved['endorsed'].should == comment.endorsed
      retrieved['id'].should == comment.id.to_s
      retrieved['children'].should be_nil
      retrieved['votes']['point'].should == comment.votes_point
      retrieved['depth'].should == comment.depth
      retrieved['parent_id'].should == comment.parent_ids.map(&:to_s)[-1]
    end

    it 'retrieve information of a single comment with its sub comments' do
      comment = thread.comments.first
      get "/api/v1/comments/#{comment.id}", recursive: true
      last_response.should be_ok
      retrieved = parse last_response.body
      retrieved['body'].should == comment.body
      retrieved['endorsed'].should == comment.endorsed
      retrieved['id'].should == comment.id.to_s
      retrieved['votes']['point'].should == comment.votes_point

      retrieved_children = retrieved['children']
      retrieved_children.length.should == comment.children.length

      comment.children.each_with_index do |child, index|
        expect(retrieved_children[index]).to include('body' => child.body, 'parent_id' => comment.id.to_s)
      end
    end

    it 'returns 400 when the comment does not exist' do
      get '/api/v1/comments/does_not_exist'
      last_response.status.should == 400
      parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
    end

    def test_unicode_data(text)
      comment = create(:comment, body: text)
      get "/api/v1/comments/#{comment.id}"
      last_response.should be_ok
      parse(last_response.body)['body'].should == text
    end

    include_examples 'unicode data'
  end

  describe 'PUT /api/v1/comments/:comment_id' do
    def test_update_endorsed(true_val, false_val)
      comment = thread.comments.first
      before = DateTime.now
      put "/api/v1/comments/#{comment.id}", endorsed: true_val, endorsement_user_id: "#{User.first.id}"
      after = DateTime.now
      last_response.should be_ok
      comment.reload
      comment.endorsed.should == true
      comment.endorsement.should_not be_nil
      comment.endorsement["user_id"].should == "#{User.first.id}"
      comment.endorsement["time"].should be_between(before, after)
      put "/api/v1/comments/#{comment.id}", endorsed: false_val
      last_response.should be_ok
      comment.reload
      comment.endorsed.should == false
      comment.endorsement.should be_nil
    end

    it 'updates endorsed correctly' do
      test_update_endorsed(true, false)
    end

    it 'updates endorsed correctly with Pythonic values' do
      test_update_endorsed('True', 'False')
    end

    it 'updates body correctly' do
      comment = thread.comments.first
      put "/api/v1/comments/#{comment.id}", body: 'new body'
      last_response.should be_ok
      comment.reload
      comment.body.should == 'new body'
    end

    it 'can update endorsed and body simultaneously' do
      comment = thread.comments.first
      put "/api/v1/comments/#{comment.id}", body: 'new body', endorsed: true
      last_response.should be_ok
      comment.reload
      comment.body.should == 'new body'
      comment.endorsed.should == true
    end

    it 'returns 400 when the comment does not exist' do
      put '/api/v1/comments/does_not_exist', body: 'new body', endorsed: true
      last_response.status.should == 400
      parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
    end

    it 'returns 503 and does not update when the post hash is blocked' do
      blocked_hash = block_post_body(BLOCKED_BODY)
      comment = thread.comments.first
      original_body = comment.body
      put "/api/v1/comments/#{comment.id}", body: BLOCKED_BODY, endorsed: true
      last_response.status.should == 503
      parse(last_response.body).first.should == I18n.t(:blocked_content_with_body_hash, :hash => blocked_hash)
      comment.reload
      comment.body.should == original_body
    end

    def test_unicode_data(text)
      comment = thread.comments.first
      put "/api/v1/comments/#{comment.id}", body: text
      last_response.should be_ok
      comment.reload
      comment.body.should == text
    end

    include_examples 'unicode data'
  end

  describe 'POST /api/v1/comments/:comment_id' do
    it 'creates a sub comment to the comment' do
      comment = thread.comments.first
      previous_child_count = comment.children.length
      user = thread.author
      body = 'new comment'
      course_id = '1'
      post "/api/v1/comments/#{comment.id}", body: body, course_id: course_id, user_id: user.id
      last_response.should be_ok

      comment.reload
      comment.children.length.should == previous_child_count + 1
      sub_comment = comment.children.order_by(created_at: :desc).first
      sub_comment.body.should == body
      sub_comment.course_id.should == course_id
      sub_comment.author.should == user
    end

    it 'returns 400 when the comment does not exist' do
      post '/api/v1/comments/does_not_exist', body: 'new comment', course_id: '1', user_id: thread.author.id
      last_response.status.should == 400
      parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
    end

    it 'returns 503 and does not create when the post hash is blocked' do
      blocked_hash = block_post_body(BLOCKED_BODY)
      comment = thread.comments.first
      user = comment.author
      post "/api/v1/comments/#{comment.id}", body: BLOCKED_BODY, course_id: '1', user_id: user.id
      last_response.status.should == 503
      parse(last_response.body).first.should == I18n.t(:blocked_content_with_body_hash, :hash => blocked_hash)
      Comment.where(body: BLOCKED_BODY).to_a.should be_empty
    end

    def test_unicode_data(text)
      parent = thread.comments.first
      post "/api/v1/comments/#{parent.id}", body: text, course_id: parent.course_id, user_id: User.first.id
      last_response.should be_ok
      parent.children.where(body: text).should_not be_empty
    end

    include_examples 'unicode data'
  end

  describe 'DELETE /api/v1/comments/:comment_id' do
    it 'delete the comment and its sub comments' do
      comment = thread.comments.first
      cnt_comments = comment.descendants_and_self.length
      prev_count = Comment.count
      delete "/api/v1/comments/#{comment.id}"
      Comment.count.should == prev_count - cnt_comments
      Comment.all.select { |c| c.id == comment.id }.first.should be_nil
    end

    it 'can delete a sub comment' do
      # Sort to ensure we get the thread's first comment, rather than the child of that comment.
      parent_comment = thread.comments.sort_by(&:_id).first
      child_comment = parent_comment.children.first
      delete "/api/v1/comments/#{child_comment.id}"

      Comment.where(:id => child_comment.id).should be_empty
      parent_comment.children.where(:id => child_comment.id).should be_empty
    end

    it 'returns 400 when the comment does not exist' do
      delete '/api/v1/comments/does_not_exist'
      last_response.status.should == 400
      parse(last_response.body).first.should == I18n.t(:requested_object_not_found)
    end
  end
end
