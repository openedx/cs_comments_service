require 'spec_helper'
require 'unicode_shared_examples'

describe "app" do
  describe "search" do

    before (:each) { set_api_key_header }

    let(:author) { create_test_user(42) }

    describe "GET /api/v1/search/threads" do
      it "returns the correct values for total_results and num_pages", :focus => true do
        course_id = "test_course_id"
        for i in 1..100 do
          text = "all"
          text += " half" if i % 2 == 0
          text += " quarter" if i % 4 == 0
          text += " tenth" if i % 10 == 0
          text += " one" if i == 100
          # There is currently a bug that causes only 10 threads with matching
          # titles/bodies to be considered, so this test case uses comments.
          thread = make_thread(author, "dummy text", course_id, "dummy_commentable")
          make_comment(author, thread, text)
        end
        # Elasticsearch does not necessarily make newly indexed content
        # available immediately, so we must explicitly refresh the index
        CommentThread.tire.index.refresh
        Comment.tire.index.refresh

        test_text = lambda do |text, expected_total_results, expected_num_pages|
          get "/api/v1/search/threads", course_id: course_id, text: text, per_page: "10"
          last_response.should be_ok
          result = parse(last_response.body)
          result["total_results"].should == expected_total_results
          result["num_pages"].should == expected_num_pages
        end

        test_text.call("all", 100, 10)
        test_text.call("half", 50, 5)
        test_text.call("quarter", 25, 3)
        test_text.call("tenth", 10, 1)
        test_text.call("one", 1, 1)
      end

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
