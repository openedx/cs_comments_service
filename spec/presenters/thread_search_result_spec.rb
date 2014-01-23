require 'spec_helper'

describe ThreadSearchResultsPresenter do
  context "#to_hash" do
  
    before(:each) { setup_10_threads }

    # NOTE: throrough coverage of search result hash structure is presently provided in spec/api/search_spec
    def check_search_result_hash(search_result, hash)
      hash["highlighted_body"].should == ((search_result.highlight[:body] || []).first || hash["body"])
      hash["highlighted_title"].should == ((search_result.highlight[:title] || []).first || hash["title"])
    end

    def check_search_results_hash(search_results, hashes)
      expected_order = search_results.map {|t| t.id}
      actual_order = hashes.map {|h| h["id"].to_s}
      actual_order.should == expected_order
      hashes.each_with_index { |hash, i| check_search_result_hash(search_results[i], hash) }
    end

    it "presents search results in correct order" do
      threads_random_order = @threads.values.shuffle
      mock_results = threads_random_order.map do |t| 
        double(Tire::Results::Item, :id => t._id.to_s, :highlight => {:body => ["foo"], :title => ["bar"]})
      end
      pres = ThreadSearchResultsPresenter.new(mock_results, nil, DFLT_COURSE_ID)
      check_search_results_hash(mock_results, pres.to_hash)
    end

    it "presents search results with correct default highlights" do
      threads_random_order = @threads.values.shuffle
      mock_results = threads_random_order.map do |t| 
        double(Tire::Results::Item, :id => t._id.to_s, :highlight => {})
      end
      pres = ThreadSearchResultsPresenter.new(mock_results, nil, DFLT_COURSE_ID)
      check_search_results_hash(mock_results, pres.to_hash)
    end

  end
end
