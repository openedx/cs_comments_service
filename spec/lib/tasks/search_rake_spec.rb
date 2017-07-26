require 'spec_helper'
require 'elasticsearch'

describe "search:rebuild_index" do
  include_context "rake"

  before do
    TaskHelpers::ElasticsearchHelper.stub(:rebuild_index)
  end

  its(:prerequisites) { should include("environment") }

  it "calls rebuild_index with defaults" do
    TaskHelpers::ElasticsearchHelper.should_receive(:rebuild_index).with(Content::ES_INDEX_NAME, 500, 0, 5)

    subject.invoke
  end

  it "calls rebuild_index with arguments" do
    # Rake calls receive arguments as strings.
    call_move_alias = 'false'
    batch_size = '100'
    sleep_time = '2'
    extra_catchup_minutes = '10'
    TaskHelpers::ElasticsearchHelper.should_receive(:rebuild_index).with(
          nil, batch_size.to_i, sleep_time.to_i, extra_catchup_minutes.to_i
    )

    subject.invoke(call_move_alias, batch_size, sleep_time, extra_catchup_minutes)
  end
end

describe "search:catchup" do
  include_context "rake"

  before do
    TaskHelpers::ElasticsearchHelper.stub(:catchup_index)
  end

  its(:prerequisites) { should include("environment") }

  it "calls catchup with defaults" do
    TaskHelpers::ElasticsearchHelper.should_receive(:catchup_index).with(
        anything, Content::ES_INDEX_NAME, 500, 0
    ) do |start_time_arg|
      start_time_arg.should be_within(1.second).of Time.now
    end

    subject.invoke
  end

  it "calls catchup with arguments" do
    # Rake calls receive arguments as strings.
    minutes = '2'
    index_name = 'some_index'
    batch_size = '100'
    sleep_time = '2'
    TaskHelpers::ElasticsearchHelper.should_receive(:catchup_index).with(
        anything, index_name, batch_size.to_i, sleep_time.to_i
    ) do |start_time_arg|
      start_time_arg.should be_within((60 * minutes.to_i + 1).second).of Time.now
    end

    subject.invoke(minutes, index_name, batch_size, sleep_time)
  end
end
