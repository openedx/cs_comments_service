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
      expect(last_response).to be_ok
      expect(last_response.content_type).to eq('application/json')
    end

    it 'retrieves information of a single comment' do
      comment = thread.comments.first
      get "/api/v1/comments/#{comment.id}"
      expect(last_response).to be_ok
      retrieved = parse last_response.body
      expect(retrieved['body']).to eq(comment.body)
      expect(retrieved['endorsed']).to eq(comment.endorsed)
      expect(retrieved['id']).to eq(comment.id.to_s)
      expect(retrieved['children']).to be_nil
      expect(retrieved['votes']['point']).to eq(comment.votes_point)
      expect(retrieved['depth']).to eq(comment.depth)
      expect(retrieved['parent_id']).to eq(comment.parent_ids.map(&:to_s)[-1])
      expect(retrieved["child_count"]).to eq(comment.children.length)
    end

    it 'retrieves information of a single comment with its sub comments' do
      comment = thread.comments.first
      get "/api/v1/comments/#{comment.id}", recursive: true
      expect(last_response).to be_ok
      retrieved = parse last_response.body
      expect(retrieved['body']).to eq(comment.body)
      expect(retrieved['endorsed']).to eq(comment.endorsed)
      expect(retrieved['id']).to eq(comment.id.to_s)
      expect(retrieved['votes']['point']).to eq(comment.votes_point)

      retrieved_children = retrieved['children']
      expect(retrieved_children.length).to eq(comment.children.length)
      expect(retrieved["child_count"]).to eq(comment.children.length)

      comment.children.each_with_index do |child, index|
        expect(retrieved_children[index]).to include('body' => child.body, 'parent_id' => comment.id.to_s)
      end
    end

    it 'retrieves information of a single comment and fixes incorrect child count' do
      comment = thread.comments.first
      comment.set(child_count: 2000)
      comment_hash = comment.to_hash(recursive: true)
      expect(comment_hash["child_count"]).to eq(2000)
      get "/api/v1/comments/#{comment.id}", recursive: true
      expect(last_response).to be_ok
      retrieved = parse last_response.body
      expect(retrieved["child_count"]).to eq(comment.children.length)

      comment.set(child_count: nil)
      get "/api/v1/comments/#{comment.id}"
      expect(last_response).to be_ok
      retrieved = parse last_response.body
      expect(retrieved["child_count"]).to eq(comment.children.length)
    end

    it 'returns 400 when the comment does not exist' do
      get '/api/v1/comments/does_not_exist'
      expect(last_response.status).to eq(400)
      expect(parse(last_response.body).first).to eq(I18n.t(:requested_object_not_found))
    end

    def test_unicode_data(text)
      comment = create(:comment, body: text)
      get "/api/v1/comments/#{comment.id}"
      expect(last_response).to be_ok
      expect(parse(last_response.body)['body']).to eq(text)
    end

    include_examples 'unicode data'
  end

  describe 'PUT /api/v1/comments/:comment_id' do
    def test_update_endorsed(true_val, false_val)
      comment = thread.comments.first
      before = DateTime.now
      put "/api/v1/comments/#{comment.id}", endorsed: true_val, endorsement_user_id: User.first.id
      after = DateTime.now
      expect(last_response).to be_ok
      comment.reload
      expect(comment.endorsed).to eq(true)
      expect(comment.endorsement).not_to be_nil
      expect(comment.endorsement["user_id"]).to eq("#{User.first.id}")
      expect(comment.endorsement["time"]).to be_between(before, after)
      put "/api/v1/comments/#{comment.id}", endorsed: false_val
      expect(last_response).to be_ok
      comment.reload
      expect(comment.endorsed).to eq(false)
      expect(comment.endorsement).to be_nil
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
      put "/api/v1/comments/#{comment.id}", body: 'new body', editing_user_id: User.first.id, edit_reason_code: "test_reason"
      expect(last_response).to be_ok
      comment.reload
      expect(comment.body).to eq 'new body'
      edit_history = comment.edit_history.map(&:to_hash)
      expect(edit_history.length).to eq 1
      expect(edit_history[0]["original_body"]).to eq original_body
      expect(edit_history[0]["reason_code"]).to eq "test_reason"
      expect(edit_history[0]["editor_username"]).to eq User.first.id
    end

    it 'updates body correctly without user_id' do
      comment = thread.comments.first
      original_body = comment.body
      put "/api/v1/comments/#{comment.id}", body: 'new body'
      expect(last_response).to be_ok
      comment.reload
      expect(comment.body).to eq 'new body'
      # This won't update edit history without a user
      edit_history = comment.edit_history.map(&:to_hash)
      expect(edit_history.length).to eq 0
    end

    it 'can update endorsed and body simultaneously' do
      comment = thread.comments.first
      put "/api/v1/comments/#{comment.id}", body: 'new body', endorsed: true, user_id: User.first.id
      expect(last_response).to be_ok
      comment.reload
      expect(comment.body).to eq('new body')
      expect(comment.endorsed).to eq(true)
    end

    it 'returns 400 when the comment does not exist' do
      put '/api/v1/comments/does_not_exist', body: 'new body', endorsed: true
      expect(last_response.status).to eq(400)
      expect(parse(last_response.body).first).to eq(I18n.t(:requested_object_not_found))
    end

    it 'returns 503 and does not update when the post hash is blocked' do
      blocked_hash = block_post_body(BLOCKED_BODY)
      comment = thread.comments.first
      original_body = comment.body
      put "/api/v1/comments/#{comment.id}", body: BLOCKED_BODY, endorsed: true, user_id: User.first.id
      expect(last_response.status).to eq(503)
      expect(parse(last_response.body).first).to eq(I18n.t(:blocked_content_with_body_hash, :hash => blocked_hash))
      comment.reload
      expect(comment.body).to eq(original_body)
    end

    def test_unicode_data(text)
      comment = thread.comments.first
      put "/api/v1/comments/#{comment.id}", body: text, user_id: User.first.id
      expect(last_response).to be_ok
      comment.reload
      expect(comment.body).to eq(text)
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
      expect(last_response).to be_ok

      comment.reload
      expect(comment.children.length).to eq(previous_child_count + 1)
      expect(comment.child_count).to eq(previous_child_count + 1)
      sub_comment = comment.children.order_by(created_at: :desc).first
      expect(sub_comment.body).to eq(body)
      expect(sub_comment.course_id).to eq(course_id)
      expect(sub_comment.author).to eq(user)
      expect(sub_comment.child_count).to eq(0)

      test_thread_marked_as_read(thread.id, user.id)
    end

    it 'returns 400 when the comment does not exist' do
      post '/api/v1/comments/does_not_exist', body: 'new comment', course_id: '1', user_id: thread.author.id
      expect(last_response.status).to eq(400)
      expect(parse(last_response.body).first).to eq(I18n.t(:requested_object_not_found))
    end

    it 'returns 503 and does not create when the post hash is blocked' do
      blocked_hash = block_post_body(BLOCKED_BODY)
      comment = thread.comments.first
      user = comment.author
      post "/api/v1/comments/#{comment.id}", body: BLOCKED_BODY, course_id: '1', user_id: user.id
      expect(last_response.status).to eq(503)
      expect(parse(last_response.body).first).to eq(I18n.t(:blocked_content_with_body_hash, :hash => blocked_hash))
      expect(Comment.where(body: BLOCKED_BODY).to_a).to be_empty
    end

    def test_unicode_data(text)
      parent = thread.comments.first
      post "/api/v1/comments/#{parent.id}", body: text, course_id: parent.course_id, user_id: User.first.id
      expect(last_response).to be_ok
      expect(parent.children.where(body: text)).not_to be_empty
    end

    include_examples 'unicode data'
  end

  describe 'DELETE /api/v1/comments/:comment_id' do
    it 'deletes the comment and its sub comments' do
      comment = thread.comments.first
      cnt_comments = comment.descendants_and_self.length
      prev_count = Comment.count
      delete "/api/v1/comments/#{comment.id}"
      expect(Comment.count).to eq(prev_count - cnt_comments)
      expect(Comment.all.select { |c| c.id == comment.id }.first).to be_nil
    end

    it 'can delete a sub comment' do
      # Sort to ensure we get the thread's first comment, rather than the child of that comment.
      parent_comment = thread.comments.sort_by(&:_id).first
      child_comment = parent_comment.children.first
      delete "/api/v1/comments/#{child_comment.id}"

      expect(Comment.where(:id => child_comment.id)).to be_empty
      expect(parent_comment.children.where(:id => child_comment.id)).to be_empty
    end

    it 'returns 400 when the comment does not exist' do
      delete '/api/v1/comments/does_not_exist'
      expect(last_response.status).to eq(400)
      expect(parse(last_response.body).first).to eq(I18n.t(:requested_object_not_found))
    end
  end


  describe "GET /api/v1/comments" do
    before(:each) { setup_comments }

    it "doesn't allow retrieving all comments" do
      get "/api/v1/comments"
      expect(last_response).not_to be_ok
    end

    let(:user) { User.first }

    it "does not allow filtering only by user" do
      get "/api/v1/comments", user_id: user.id
      expect(last_response).not_to be_ok
    end

    it "does not allow filtering only by course" do
      get "/api/v1/comments", course_id: "abc"
      expect(last_response).not_to be_ok
    end

    it "allows filtering by course and user" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc"
      expect(last_response).to be_ok
      parsed = parse last_response.body
      expect(parsed["comment_count"]).to eq(25)
      for item in parsed["collection"]
        expect(item["username"]).to eq(user.username)
        expect(item["course_id"]).to eq("abc")
      end
    end

    it "allows filtering by flagged status" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", flagged: true
      expect(last_response).to be_ok
      parsed = parse last_response.body
      expect(parsed["comment_count"]).to eq(5)
      for item in parsed["collection"]
        expect(item["abuse_flaggers"]).not_to be_empty
      end
    end

    it "paginates the comments with default values" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc"
      parsed = parse last_response.body
      expect(parsed["page"]).to  eq(1)
      expect(parsed["collection"].length).to  eq(DEFAULT_PER_PAGE)
      expect(parsed["num_pages"]).to  eq((25 / DEFAULT_PER_PAGE.to_f).ceil)
    end

    it "allows specifying a page size" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", per_page: 5
      expect(last_response).to be_ok
      parsed = parse last_response.body
      expect(parsed["collection"].length).to eq(5)
      expect(parsed["num_pages"]).to eq(5)
    end

    it "allows specifying a page number" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", page: 2
      parsed = parse last_response.body
      expect(parsed["page"]).to eq(2)
    end

    it "handles the end of pagination correctly" do
      get "/api/v1/comments", user_id: user.id, course_id: "abc", page: 2
      parsed = parse last_response.body
      expect(parsed["collection"].length).to eq(5)
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


      expect(all_items["collection"]).to eq(
        page_1["collection"] +
        page_2["collection"] +
        page_3["collection"]
      )
    end
  end
end
