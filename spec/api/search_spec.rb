require 'spec_helper'
require 'unicode_shared_examples'

describe "app" do
  describe "search" do
    let(:author) { create_test_user(42) }

    describe "GET /api/v1/search/threads" do
      def test_unicode_data(text)
        # Elasticsearch may not be able to handle searching for non-ASCII text,
        # so prepend the text with an ASCII term we can search for.
        search_term = "artichoke"
        course_id = "unicode_course"
        thread = make_thread(author, "#{search_term} #{text}", course_id, "unicode_commentable")
        make_comment(author, thread, text)
        # Elasticsearch does not necessarily make newly indexed content
        # available immediately, so we must explicitly refresh the index
        CommentThread.tire.index.refresh
        get "/api/v1/search/threads", course_id: course_id, text: search_term
        last_response.should be_ok
        result = parse(last_response.body)["collection"]
        result.length.should == 1
        check_thread_result_json(nil, thread, result.first, true)
      end

      include_examples "unicode data"
    end
  end
end
