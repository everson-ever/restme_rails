# frozen_string_literal: true

require "restme_rails"
require "amazing_print"
require "byebug"
require "database_cleaner/active_record"
require "ostruct"
require "timecop"
require "dotenv/load"

require_relative "support/database"
require_relative "support/matchers/execute_queries_matcher"
require_relative "support/controllers/products_controller"
require_relative "support/controllers/establishments_controller"
require_relative "support/controllers/settings_controller"
require_relative "support/rules/product_rules/authorize/rules"
require_relative "support/rules/product_rules/scope/rules"
require_relative "support/rules/product_rules/field/rules"
require_relative "support/rules/product_rules/create/rules"
require_relative "support/rules/product_rules/update/rules"
require_relative "support/rules/establishment_rules/authorize/rules"
require_relative "support/rules/establishment_rules/scope/rules"
require_relative "support/rules/establishment_rules/field/rules"
require_relative "support/request_mock"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
