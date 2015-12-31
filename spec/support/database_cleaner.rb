require 'database_cleaner'

RSpec.configure do |config|
  config.before(:suite) do
    # Mongoid only supports truncation.
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
