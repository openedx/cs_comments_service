require 'rspec/expectations'

RSpec::Matchers.define :be_an_empty_response do
  match do |actual|
    actual.body == '{}'
  end
end
