require 'spec_helper'

describe ThreadPresenter do

  context "#to_hash" do
    let(:default_resp_limit) { CommentService.config["thread_response_default_size"] }

    def random_flag_abuses!(comment)
      # Flip a coin
      flag_abuse = Random.rand(1..2) == 1
      unless flag_abuse
        return false
      end
      abuse_flaggers = []
      if flag_abuse
        # Create a random number (from 1 to 5) of flaggers with random ids from 100 to 200
        abuse_flaggers = Array.new(Random.rand(1..5)) { Random.rand(100..200) }
      end
      comment.abuse_flaggers = abuse_flaggers
      comment.save!
      true
    end

    shared_examples "to_hash arguments" do |thread_type, endorse_responses|
      before(:each) do
        User.all.delete
        Content.all.delete

        course_id, commentable_id = ['foo', 'bar']

        @thread_no_responses = make_thread(
          create_test_user('author1'),
          'thread with no responses',
          course_id, commentable_id,
          thread_type
        )

        @thread_one_empty_response = make_thread(
          create_test_user('author2'),
          'thread with one response',
          course_id, commentable_id,
          thread_type
        )
        make_comment(create_test_user('author3'), @thread_one_empty_response, 'empty response')

        @thread_one_response = make_thread(
          create_test_user('author4'),
          'thread with one response and some comments',
          course_id, commentable_id,
          thread_type
        )
        resp = make_comment(
          create_test_user('author5'),
          @thread_one_response,
          'a response'
        )
        make_comment(create_test_user('author6'), resp, 'first comment')
        make_comment(create_test_user('author7'), resp, 'second comment')
        make_comment(create_test_user('author8'), resp, 'third comment')
        @abuse_flag_counts = 0

        @thread_ten_responses = make_thread(
          create_test_user('author9'),
          'thread with ten responses',
          course_id, commentable_id,
          thread_type
        )
        (1..10).each do |n|
          resp = make_comment(create_test_user("author#{n+10}"), @thread_ten_responses, "response #{n}")
          if random_flag_abuses!(resp)
            @abuse_flag_counts += 1
          end
          (1..3).each do |n2|
            resp_to_resp = make_comment(create_test_user("author#{n+10}+#{n2}"), resp, "comment #{n+10}+#{n}")
            if random_flag_abuses!(resp_to_resp)
              @abuse_flag_counts += 1
            end
          end
        end

        if endorse_responses
          [
            @thread_one_empty_response.comments.first,
            @thread_one_response.comments.first,
            @thread_ten_responses.comments[0],
            @thread_ten_responses.comments[2],
            @thread_ten_responses.comments[6]
          ].each do |response|
            response.endorsed = true
            response.endorsement = {:user_id => "1", :time => DateTime.now}
            response.save!
          end
        end

        @threads_with_num_comments = [
          [@thread_no_responses, 0],
          [@thread_one_empty_response, 1],
          [@thread_one_response, 4],
          [@thread_ten_responses, 40]
        ]

        @reader = create_test_user('thread reader')
      end

      it "handles with_responses=false and recursive has no impact" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          # with response=false and recursive=false
          hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(false, 0, nil, false)
          check_thread_result(@reader, thread, hash)
          ['children', 'resp_skip', 'resp_limit', 'resp_total'].each {|k| expect(hash.has_key? k).to be false }
          # with response=false and recursive=true
          hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(false, 0, nil, true)
          check_thread_result(@reader, thread, hash)
          ['children', 'resp_skip', 'resp_limit', 'resp_total'].each {|k| expect(hash.has_key? k).to be false }
        end
      end

      it "handles with_responses=true and recursive=true" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, 0, default_resp_limit, true)
          check_thread_result(@reader, thread, hash)
          check_thread_response_paging(thread, hash, 0, default_resp_limit, false, true)
        end
      end

      it "handles with_responses=true and recursive=false" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, 0, default_resp_limit, false)
          check_thread_result(@reader, thread, hash)
          check_thread_response_paging(thread, hash, 0, default_resp_limit)
        end
      end

      it "handles skip with no limit" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          [0, 1, 2, 9, 10, 11, 1000].each do |skip|
            hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, skip, default_resp_limit, true)
            check_thread_result(@reader, thread, hash)
            check_thread_response_paging(thread, hash, skip, default_resp_limit)
          end
        end
      end

      it "handles skip and limit" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          [1, 2, 3, 9, 10, 11, 1000].each do |limit|
            [0, 1, 2, 9, 10, 11, 1000].each do |skip|
              hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, skip, limit, true)
              check_thread_result(@reader, thread, hash)
              check_thread_response_paging(thread, hash, skip, limit)
            end
          end
        end
      end

      it "handles reversed_order and recursive" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, 0, default_resp_limit, true, false, true)
          check_thread_result(@reader, thread, hash)
          check_thread_response_paging(thread, hash, 0, default_resp_limit, false, false, true)
        end
      end

      it "handles merge_question_type_responses=true" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, 0, default_resp_limit, true, false, true, true)
          check_thread_result(@reader, thread, hash)
          check_thread_response_paging(thread, hash, 0, default_resp_limit, false, false, true, true)
        end
      end

      it "handles reversed_order and recursive with skip and limit" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          [1, 2, 3, 9, 10, 11, 1000].each do |limit|
            [0, 1, 2, 9, 10, 11, 1000].each do |skip|
              hash = ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, skip, limit, true, false, true)
              check_thread_result(@reader, thread, hash)
              check_thread_response_paging(thread, hash, skip, limit, false, false, true)
            end
          end
        end
      end

      it "fails with invalid arguments" do
        @threads_with_num_comments.each do |thread, num_comments|
          is_endorsed = num_comments > 0 && endorse_responses
          expect{ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, -1, nil, true)}.to raise_error(ArgumentError)
          [-1, 0].each do |limit|
            expect{ThreadPresenter.new(thread, @reader, false, num_comments, is_endorsed, nil).to_hash(true, 0, limit, true)}.to raise_error(ArgumentError)
          end
        end
      end
      it "returns the correct abuse flagged count" do
        pres = ThreadPresenter.factory(@thread_ten_responses, @reader, true).to_hash
        expect(pres["abuse_flagged_count"]).to eq @abuse_flag_counts
      end
    end

    [:discussion, :question].each do |thread_type|
      [false, true].each do |endorsed_responses|
        context "for a #{thread_type} thread #{endorsed_responses ? "with" : "without"} endorsed responses" do
          include_examples "to_hash arguments", thread_type, endorsed_responses
        end
      end
    end
  end

  context "#merge_response_content" do

    before(:each) { @cid_seq = 10 }

    def make_comment(parent=nil)
      c = Comment.new
      c.id = @cid_seq
      @cid_seq += 1
      c.parent_id = parent.nil? ? nil : parent.id
      c
    end

    it "nests comments in the correct order" do
      c0 = make_comment()
      c00 = make_comment(c0)
      c01 = make_comment(c0)
      c010 = make_comment(c01)

      pres = ThreadPresenter.new(nil, nil, nil, nil, nil, nil)
      responses = pres.merge_response_content([c0, c00, c01, c010])
      expect(responses.size).to eq(1) # c0
      expect(responses[0]["id"]).to eq(c0.id)
      expect(responses[0]["children"].size).to eq(2) # c00, c01
      expect(responses[0]["children"][0]["id"]).to eq(c00.id)
      expect(responses[0]["children"][1]["id"]).to eq(c01.id)
      expect(responses[0]["children"][1]["children"].size).to eq(1) # c010
      expect(responses[0]["children"][1]["children"][0]["id"]).to eq(c010.id)
    end

    it "handles orphaned child comments gracefully" do
      c0 = make_comment()
      c00 = make_comment(c0)
      c000 = make_comment(c00)
      c1 = make_comment()
      c10 = make_comment(c1)
      c11 = make_comment(c1)
      c111 = make_comment(c11)
      # lose c0 and c11 from result set.  their descendants should
      # be silently skipped over.

      pres = ThreadPresenter.new(nil, nil, nil, nil, nil, nil)
      responses = pres.merge_response_content([c00, c000, c1, c10, c111])
      expect(responses.size).to eq(1) # c1
      expect(responses[0]["id"]).to eq(c1.id)
      expect(responses[0]["children"].size).to eq(1) # c10
      expect(responses[0]["children"][0]["id"]).to eq(c10.id)
    end
  end
end

