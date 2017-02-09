require 'spec_helper'
require 'elasticsearch'

describe UnicornHelpers do
  include_context 'search_enabled'

  context("#exit_on_invalid_index") do
    subject { UnicornHelpers.exit_on_invalid_index }

    it "doesn't exit when index is valid" do
      # code 101 is special code recongnized by forum-supervisor.sh
      lambda{subject}.should_not exit_with_code(101)
    end

    it "exits when index is invalid" do
      TaskHelpers::ElasticsearchHelper.delete_index(Content::ES_INDEX_NAME)
      # code 101 is special code recongnized by forum-supervisor.sh
      lambda{subject}.should exit_with_code(101)
    end

  end
end
