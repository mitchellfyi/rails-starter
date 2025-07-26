# frozen_string_literal: true

# Synth Testing module installer for the Rails SaaS starter template.
# This module sets up comprehensive testing infrastructure with factories and mocks.

say_status :testing, "Installing testing module with RSpec, factories, and mocks"

# Add testing gems
add_gem 'rspec-rails', '~> 7.1', group: [:development, :test]
add_gem 'factory_bot_rails', '~> 6.4', group: [:development, :test]
add_gem 'faker', '~> 3.5', group: [:development, :test]
add_gem 'webmock', '~> 3.24', group: :test
add_gem 'vcr', '~> 6.3', group: :test
add_gem 'capybara', '~> 3.40', group: :test
add_gem 'selenium-webdriver', '~> 4.27', group: :test
add_gem 'database_cleaner-active_record', '~> 2.2', group: :test

after_bundle do
  # Install RSpec
  generate 'rspec:install'

  # Create factory_bot configuration
  create_file 'spec/support/factory_bot.rb', <<~'RUBY'
    RSpec.configure do |config|
      config.include FactoryBot::Syntax::Methods
    end
  RUBY

  # Create webmock configuration
  create_file 'spec/support/webmock.rb', <<~'RUBY'
    require 'webmock/rspec'

    RSpec.configure do |config|
      config.before(:each) do
        WebMock.reset!
        
        # Disable external HTTP requests by default
        WebMock.disable_net_connect!(allow_localhost: true)
        
        # Allow local test server connections
        WebMock.disable_net_connect!(
          allow_localhost: true,
          allow: ['127.0.0.1', 'localhost', 'chromedriver.storage.googleapis.com']
        )
      end
    end

    # Mock external services
    def stub_openai_api
      WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 200,
          body: {
            choices: [
              {
                message: {
                  content: "This is a mocked OpenAI response"
                }
              }
            ],
            usage: { total_tokens: 100 },
            model: "gpt-4o-mini"
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    def stub_stripe_api
      WebMock.stub_request(:post, /api\.stripe\.com/)
        .to_return(
          status: 200,
          body: { id: 'stripe_mock_id', object: 'charge' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end
  RUBY

  # Create VCR configuration
  create_file 'spec/support/vcr.rb', <<~'RUBY'
    require 'vcr'

    VCR.configure do |config|
      config.cassette_library_dir = 'spec/vcr_cassettes'
      config.hook_into :webmock
      config.configure_rspec_metadata!
      config.allow_http_connections_when_no_cassette = false
      
      # Filter sensitive data
      config.filter_sensitive_data('<OPENAI_API_KEY>') { Rails.application.credentials.openai&.api_key }
      config.filter_sensitive_data('<STRIPE_SECRET_KEY>') { Rails.application.credentials.stripe&.secret_key }
      config.filter_sensitive_data('<GITHUB_TOKEN>') { Rails.application.credentials.github&.token }
    end
  RUBY

  # Create Capybara configuration
  create_file 'spec/support/capybara.rb', <<~'RUBY'
    require 'capybara/rails'
    require 'capybara/rspec'
    require 'selenium-webdriver'

    Capybara.configure do |config|
      config.default_driver = :rack_test
      config.javascript_driver = :selenium_chrome_headless
      config.default_max_wait_time = 5
      config.server = :puma, { Silent: true }
    end

    # Chrome headless configuration
    Capybara.register_driver :selenium_chrome_headless do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-gpu')
      options.add_argument('--window-size=1400,1400')
      
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
    end
  RUBY

  # Create database cleaner configuration
  create_file 'spec/support/database_cleaner.rb', <<~'RUBY'
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

  # Create shared examples
  create_file 'spec/support/shared_examples.rb', <<~'RUBY'
    RSpec.shared_examples 'authenticated endpoint' do
      context 'when not authenticated' do
        it 'returns 401 unauthorized' do
          subject
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    RSpec.shared_examples 'paginated endpoint' do
      it 'includes pagination metadata' do
        subject
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['meta']).to include(
          'current_page',
          'total_pages',
          'total_count',
          'per_page'
        )
      end
    end

    RSpec.shared_examples 'validates presence of' do |field|
      it "validates presence of #{field}" do
        record = build(described_class.name.underscore.to_sym, field => nil)
        expect(record).not_to be_valid
        expect(record.errors[field]).to include("can't be blank")
      end
    end
  RUBY

  # Create test factories
  create_file 'spec/factories/users.rb', <<~'RUBY'
    FactoryBot.define do
      factory :user do
        first_name { Faker::Name.first_name }
        last_name { Faker::Name.last_name }
        email { Faker::Internet.unique.email }
        password { 'password123' }
        password_confirmation { 'password123' }
        confirmed_at { Time.current }
        
        trait :admin do
          admin { true }
        end
        
        trait :with_api_token do
          after(:create) do |user|
            create(:api_token, user: user)
          end
        end
      end
    end
  RUBY

  create_file 'spec/factories/api_tokens.rb', <<~'RUBY'
    FactoryBot.define do
      factory :api_token do
        user
        name { "Test Token" }
        token { SecureRandom.hex(32) }
        active { true }
        
        trait :inactive do
          active { false }
        end
      end
    end
  RUBY

  create_file 'spec/factories/prompt_templates.rb', <<~'RUBY'
    FactoryBot.define do
      factory :prompt_template do
        name { Faker::Lorem.words(number: 3).join(' ').titleize }
        content { "Generate a {{type}} for {{subject}} with the following requirements: {{requirements}}" }
        description { Faker::Lorem.sentence }
        tags { "ai,generation,template" }
        version { 1 }
        output_format { "text" }
        active { true }
        
        trait :inactive do
          active { false }
        end
        
        trait :json_output do
          output_format { "json" }
        end
      end
    end
  RUBY

  # Create test helpers
  create_file 'spec/support/auth_helpers.rb', <<~'RUBY'
    module AuthHelpers
      def sign_in_user(user = nil)
        user ||= create(:user)
        sign_in user
        user
      end
      
      def api_headers_for(user)
        token = create(:api_token, user: user)
        {
          'Authorization' => "Bearer #{token.token}",
          'X-API-Version' => 'v1',
          'Content-Type' => 'application/json'
        }
      end
      
      def authenticated_api_request(method, path, user: nil, params: {})
        user ||= create(:user)
        headers = api_headers_for(user)
        
        case method
        when :get
          get path, headers: headers, params: params
        when :post
          post path, headers: headers, params: params.to_json
        when :patch, :put
          patch path, headers: headers, params: params.to_json
        when :delete
          delete path, headers: headers
        end
      end
    end

    RSpec.configure do |config|
      config.include Devise::Test::ControllerHelpers, type: :controller
      config.include Devise::Test::IntegrationHelpers, type: :request
      config.include AuthHelpers
    end
  RUBY

  say_status :testing, "Testing module installed. Next steps:"
  say_status :testing, "1. Run bundle install"
  say_status :testing, "2. Configure CI/CD pipeline"
  say_status :testing, "3. Run bin/rspec to test the setup"
  say_status :testing, "4. Add more factories as needed"
end