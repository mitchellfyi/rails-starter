# frozen_string_literal: true

# Testing module installer for Rails SaaS Starter Template
# Sets up comprehensive test coverage with RSpec, factories, mocks, and CI

say 'Installing testing module...'

# Generate RSpec configuration
generate 'rspec:install'

# Create directories for test files
run 'mkdir -p spec/{support,factories,models,requests,system}'
run 'mkdir -p spec/{models/{ai,billing,admin},requests/api/v1,system/{ai,billing,admin}}'

# Remove default rails_helper and replace with our comprehensive version
remove_file 'spec/rails_helper.rb'
create_file 'spec/rails_helper.rb', <<~RUBY
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
      FileUtils.rm_rf(Dir["\#{Rails.root}/tmp/storage"])
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
RUBY

# Support files
create_file 'spec/support/database_cleaner.rb', <<~RUBY
  # frozen_string_literal: true

  require 'database_cleaner/active_record'

  RSpec.configure do |config|
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
RUBY

create_file 'spec/support/factory_bot.rb', <<~RUBY
  # frozen_string_literal: true

  RSpec.configure do |config|
    config.include FactoryBot::Syntax::Methods
  end
RUBY

create_file 'spec/support/capybara.rb', <<~RUBY
  # frozen_string_literal: true

  require 'capybara/rspec'

  Capybara.default_driver = :rack_test
  Capybara.javascript_driver = :selenium_chrome_headless

  RSpec.configure do |config|
    config.before(:each, type: :system) do
      driven_by(:rack_test)
    end

    config.before(:each, type: :system, js: true) do
      driven_by(:selenium_chrome_headless)
    end
  end
RUBY

create_file 'spec/support/external_service_mocks.rb', <<~RUBY
  # frozen_string_literal: true
  require 'webmock/rspec'

  # Mock configurations for external services to ensure tests run offline
  RSpec.configure do |config|
    config.before(:each) do
      # Mock OpenAI API
      stub_request(:post, /api\\.openai\\.com/)
        .to_return(
          status: 200,
          body: {
            choices: [
              {
                message: { content: 'Mocked OpenAI response' },
                finish_reason: 'stop'
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock Anthropic/Claude API
      stub_request(:post, /api\\.anthropic\\.com/)
        .to_return(
          status: 200,
          body: {
            content: [{ text: 'Mocked Claude response' }],
            stop_reason: 'end_turn'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock Stripe API
      stub_request(:any, /api\\.stripe\\.com/)
        .to_return(
          status: 200,
          body: { id: 'mocked_stripe_object' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock GitHub API
      stub_request(:get, /api\\.github\\.com/)
        .to_return(
          status: 200,
          body: { login: 'testuser', name: 'Test User' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock HTTP requests for MCP fetchers
      stub_request(:any, /example\\.com/).to_return(
        status: 200,
        body: { data: 'mocked response' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end
  end
RUBY

create_file 'spec/support/json_api_helpers.rb', <<~RUBY
  # frozen_string_literal: true

  module JsonApiHelpers
    def json_response
      JSON.parse(response.body)
    end

    def json_data
      json_response['data']
    end

    def json_errors
      json_response['errors']
    end

    def json_api_headers
      {
        'Content-Type' => 'application/vnd.api+json',
        'Accept' => 'application/vnd.api+json'
      }
    end

    def expect_json_api_error(status:, detail: nil)
      expect(response).to have_http_status(status)
      expect(json_errors).to be_present
      expect(json_errors.first['detail']).to include(detail) if detail
    end

    def expect_json_api_resource(type:, attributes: {})
      expect(json_data['type']).to eq(type)
      attributes.each do |key, value|
        expect(json_data['attributes'][key.to_s]).to eq(value)
      end
    end
  end

  RSpec.configure do |config|
    config.include JsonApiHelpers, type: :request
  end
RUBY

create_file 'spec/support/auth_helpers.rb', <<~RUBY
  # frozen_string_literal: true

  module AuthHelpers
    def sign_in_user(user = nil)
      user ||= create(:user)
      sign_in user
      user
    end

    def create_user_with_workspace(workspace_attributes = {})
      user = create(:user)
      workspace = create(:workspace, workspace_attributes)
      create(:membership, user: user, workspace: workspace, role: 'owner')
      [user, workspace]
    end

    def auth_headers(user)
      token = JWT.encode({ user_id: user.id }, Rails.application.secret_key_base)
      { 'Authorization' => "Bearer \#{token}" }
    end
  end

  RSpec.configure do |config|
    config.include Devise::Test::ControllerHelpers, type: :controller
    config.include Devise::Test::IntegrationHelpers, type: :request
    config.include Devise::Test::IntegrationHelpers, type: :system
    config.include AuthHelpers
  end
RUBY

say 'Testing module configuration files created successfully!'
say 'Run "bundle exec rspec" to execute the test suite'