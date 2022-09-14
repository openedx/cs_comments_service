require 'factory_bot'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  FactoryBot.find_definitions

  config.before(:suite) do
    MongoidCleaner.cleaning do
      FactoryBot.lint
    end
  end
end
