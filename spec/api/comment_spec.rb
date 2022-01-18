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
      last_response.content_type.should == 'application/json'
    end

    it 'retrieves information of a single comment' do
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
      retrieved["child_count"].should == comment.children.length
    end

    it 'retrieves information of a single comment with its sub comments' do
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
      retrieved["child_count"].should == comment.children.length

      comment.children.each_with_index do |child, index|
        expect(retrieved_children[index]).to include('body' => child.body, 'parent_id' => comment.id.to_s)
      end
    end

    it 'retrieves information of a single comment and fixes incorrect child count' do
      comment = thread.comments.first
      comment.set(child_count: 2000)
      comment_hash = comment.to_hash(recursive: true)
      comment_hash["child_count"].should == 2000
      get "/api/v1/comments/#{comment.id}", recursive: true
      last_response.should be_ok
      retrieved = parse last_response.body
      retrieved["child_count"].should == comment.children.length

      comment.set(child_count: nil)
      get "/api/v1/comments/#{comment.id}"
      last_response.should be_ok
      retrieved = parse last_response.body
      retrieved["child_count"].should == comment.children.length
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
      put "/api/v1/comments/#{comment.id}", endorsed: true_val, endorsement_user_id: User.first.id
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
      original_body = comment.body
      put "/api/v1/comments/#{comment.id}", body: 'new body', user_id: User.first.id, edit_reason_code: "test_reason"
      last_response.should be_ok
      comment.reload
      expect(comment.body).to eq 'new body'
      edit_history = comment.edit_history.map(&:to_hash)
      expect(edit_history.length).to eq 1
      expect(edit_history[0]["original_body"]).to eq original_body
      expect(edit_history[0]["reason_code"]).to eq "test_reason"
      expect(edit_history[0]["editor_username"]).to eq User.first.id
    end

    it 'can update endorsed and body simultaneously' do
      comment = thread.comments.first
      put "/api/v1/comments/#{comment.id}", body: 'new body', endorsed: true, user_id: User.first.id
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
      put "/api/v1/comments/#{comment.id}", body: BLOCKED_BODY, endorsed: true, user_id: User.first.id
      last_response.status.should == 503
      parse(last_response.body).first.should == I18n.t(:blocked_content_with_body_hash, :hash => blocked_hash)
      comment.reload
      comment.body.should == original_body
    end

    def test_unicode_data(text)
      comment = thread.comments.first
      put "/api/v1/comments/#{comment.id}", body: text, user_id: User.first.id
      last_response.should be_ok
      comment.reload
      comment.body.should == text
    end

    include_examples 'unicode data'
  end

  describe 'POST /api/v1/comments/:comment_id' do
    it 'creates a sub comment to the comment and marks thread as read for user' do
      comment = thread.comments.first
      previous_child_count = comment.children.length
      user = thread.author
      body = 'new comment'
      course_id = '1'
      post "/api/v1/comments/#{comment.id}", body: body, course_id: course_id, user_id: user.id
      last_response.should be_ok

      comment.reload
      comment.children.length.should == previous_child_count + 1
      comment.child_count.should == previous_child_count + 1
      sub_comment = comment.children.order_by(created_at: :desc).first
      sub_comment.body.should == body
      sub_comment.course_id.should == course_id
      sub_comment.author.should == user
      sub_comment.child_count.should == 0

      test_thread_marked_as_read(thread.id, user.id)
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
    it 'deletes the comment and its sub comments' do
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


  describe "GET /api/v1/comments" do
    before(:each) { setup_comments }

    it "doesn't allow retrieving all comments" do
      get "/api/v1/comments"
      last_response.should_not be_ok
    end

    let(:user) { User.first }

    it "does not allow filtering only by user" do
      get "/api/v1/comments", user_id: user.id
      last_response.should_not be_ok
    end

    it "does not allow filtering only by course" do
      get "/api/v1/comments", course_id: "abc"
      last_response.should_not be_ok
    end

    it "allows filtering by course and user" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc"
      last_response.should be_ok
      parsed = parse last_response.body
      parsed["comment_count"].should == 25
      for item in parsed["collection"]
        item["username"].should == user.username
        item["course_id"].should == "abc"
      end
    end

    it "allows filtering by flagged status" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", flagged: true
      last_response.should be_ok
      parsed = parse last_response.body
      parsed["comment_count"].should == 5
      for item in parsed["collection"]
        item["abuse_flaggers"].should_not be_empty
      end
    end

    it "paginates the comments with default values" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc"
      parsed = parse last_response.body
      parsed["page"].should == 1
      parsed["collection"].length.should == DEFAULT_PER_PAGE
      parsed["num_pages"].should == (25 / DEFAULT_PER_PAGE.to_f).ceil
    end

    it "allows specifying a page size" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", per_page: 5
      last_response.should be_ok
      parsed = parse last_response.body
      parsed["collection"].length.should == 5
      parsed["num_pages"].should == 5
    end

    it "allows specifying a page number" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", page: 2
      parsed = parse last_response.body
      parsed["page"].should == 2
    end

    it "handles the end of pagination correctly" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", page: 2
      parsed = parse last_response.body
      parsed["collection"].length.should == 5
    end

    it "returns the correct items for each page" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", per_page: 25
      all_items = parse last_response.body

      get "/api/v1/comments", user_id: user.id, course_id: "abc", page: 1
      page_1 = parse last_response.body

      get "/api/v1/comments", user_id: user.id, course_id: "abc", page: 2
      page_2 = parse last_response.body

      get "/api/v1/comments", user_id: user.id, course_id: "abc", page: 3
      page_3 = parse last_response.body


      all_items["collection"].should == (
        page_1["collection"] +
        page_2["collection"] +
        page_3["collection"]
      )
    end
  end
end
