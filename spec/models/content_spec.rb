require 'spec_helper'

describe Content do
  before :each do
    @text =
"""
hi @tom, I have a question from @pi314 about the following code:
```
class A
  def set_some_variable
    @some_variable = 1
  end
end
```
and also the following code
    class A
      def get_some_variable
        @some_variable
      end
    end
what is the 'at' symbol doing there? @dementrock
"""
  end

  describe "#get_marked_text(text)" do
    it "returns marked at text" do
      converted = Content.get_marked_text(@text)
      converted.should include "@tom_0"
      converted.should include "@pi314_1"
      converted.should include "@some_variable_2"
      converted.should include "@some_variable_3"
      converted.should include "@dementrock_4"
    end
  end

  describe "#get_valid_at_position_list(text)" do
    it "returns the list of positions for the valid @ notifications, filtering out the ones in code blocks" do
      list = Content.get_valid_at_position_list(@text)
      list.should include [0, "tom"]
      list.should include [1, "pi314"]
      list.should include [4, "dementrock"]
      list.length.should == 3
    end
  end
end
