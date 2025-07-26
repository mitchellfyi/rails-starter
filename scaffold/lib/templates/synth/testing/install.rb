# frozen_string_literal: true

# Testing module installer for Rails SaaS Starter Template
# Sets up comprehensive test coverage with RSpec, factories, mocks, and CI

say 'Installing testing module...'

# Generate RSpec configuration
generate 'rspec:install'

# Create directories for test files
run 'mkdir -p spec/{support,factories,models,requests,system}'
run 'mkdir -p spec/{models/ai,requests/api/v1,system/ai}'

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
      allow_any_instance_of(OpenAI::Client).to receive(:completions) do |args|
        {
          'choices' => [
            {
              'text' => 'Mocked OpenAI response',
              'finish_reason' => 'stop'
            }
          ]
        }
      end

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
      allow(Stripe::Customer).to receive(:create).and_return(
        double('customer', id: 'cus_test123', email: 'test@example.com')
      )
      allow(Stripe::Subscription).to receive(:create).and_return(
        double('subscription', id: 'sub_test123', status: 'active')
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

# Update rails_helper.rb to load all support files
rails_helper_path = 'spec/rails_helper.rb'
if File.exist?(rails_helper_path)
  insert_into_file rails_helper_path, after: "# Add additional requires below this line. Rails is not loaded until this point!\n" do
    <<~RUBY

      # Load all support files
      Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

      # Configure RSpec
      RSpec.configure do |config|
        # Database setup
        config.use_transactional_fixtures = true
        config.infer_spec_type_from_file_location!
        config.filter_rails_from_backtrace!

        # Ensure tests run in random order
        config.order = :random
        Kernel.srand config.seed
      end
    RUBY
  end
end

say 'Testing module support files installed successfully!'