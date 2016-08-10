require 'factory_girl'

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods

  FactoryGirl.find_definitions

  config.before(:suite) do
    MongoidCleaner.cleaning do
      FactoryGirl.lint
    end
  end
end
