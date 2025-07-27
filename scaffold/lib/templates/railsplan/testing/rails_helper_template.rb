# frozen_string_literal: true

require 'spec_helper'
require 'rspec/rails'
require 'factory_bot_rails'
require 'capybara/rspec'
require 'webmock/rspec'

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

# Load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Database setup
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Ensure tests run in random order
  config.order = :random
  Kernel.srand config.seed

  # Include helper modules
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Clean up uploaded files in test
  config.after(:each) do
    FileUtils.rm_rf(Dir["#{Rails.root}/tmp/storage"])
  end

  # Reset ActionMailer deliveries
  config.before(:each) do
    ActionMailer::Base.deliveries.clear
  end

  # Configure WebMock to allow localhost
  config.before(:suite) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end

# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end