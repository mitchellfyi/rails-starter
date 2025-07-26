# Testing Module

This module provides comprehensive testing infrastructure including RSpec configuration, factory definitions, mocking for external services, and integration testing setup.

## Features

- **RSpec Configuration**: Complete RSpec setup with Rails integration
- **Factory Bot**: Model factories with realistic test data
- **External Service Mocking**: WebMock and VCR for API testing
- **System Testing**: Capybara with headless Chrome
- **Database Management**: Database cleaner for test isolation
- **Shared Examples**: Reusable test patterns

## Installation

```bash
bin/synth add testing
```

This installs:
- RSpec with Rails integration
- FactoryBot for test data generation
- WebMock and VCR for external API mocking
- Capybara for integration testing
- Database cleaner for test isolation

## Post-Installation

1. **Run bundle install:**
   ```bash
   bundle install
   ```

2. **Run the test suite:**
   ```bash
   bundle exec rspec
   ```

3. **Generate additional factories:**
   ```bash
   rails generate factory_bot:model Post
   ```

## Usage

### Model Testing with Factories

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  let(:user) { build(:user) }

  it 'is valid with valid attributes' do
    expect(user).to be_valid
  end

  it_behaves_like 'validates presence of', :email
end
```

### API Testing with Authentication

```ruby
# spec/requests/api/v1/users_spec.rb
RSpec.describe 'Users API', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v1/users' do
    subject { authenticated_api_request(:get, '/api/v1/users', user: user) }

    it_behaves_like 'authenticated endpoint'
    it_behaves_like 'paginated endpoint'

    context 'when authenticated' do
      it 'returns users list' do
        create_list(:user, 3)
        subject
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to have(4).items # 3 + current user
      end
    end
  end
end
```

### External Service Mocking

```ruby
# Mock OpenAI API
RSpec.describe LlmProcessor do
  before { stub_openai_api }

  it 'processes prompt templates' do
    template = create(:prompt_template)
    processor = LlmProcessor.new(template, { subject: 'test' })
    
    result = processor.execute
    expect(result[:content]).to eq('This is a mocked OpenAI response')
  end
end

# Using VCR for real API recording
RSpec.describe GitHubService, vcr: true do
  it 'fetches repository data' do
    service = GitHubService.new('rails/rails')
    repo = service.fetch_repository
    
    expect(repo['name']).to eq('rails')
  end
end
```

### System Testing

```ruby
# spec/system/user_registration_spec.rb
RSpec.describe 'User Registration', type: :system do
  it 'allows user to sign up' do
    visit new_user_registration_path
    
    fill_in 'Email', with: 'test@example.com'
    fill_in 'Password', with: 'password123'
    fill_in 'Password confirmation', with: 'password123'
    
    click_button 'Sign up'
    
    expect(page).to have_content('Welcome! You have signed up successfully.')
  end
end
```

### Testing AI Components

```ruby
# spec/services/mcp_service_spec.rb
RSpec.describe McpService do
  let(:service) { McpService.new }

  describe '#fetch' do
    it 'fetches data from database provider' do
      create_list(:user, 3)
      
      result = service.fetch(:users, {
        type: 'database',
        params: { model: 'User', query_type: 'recent', limit: 2 }
      })
      
      expect(result).to have(2).items
    end

    it 'handles API provider with mocked requests', :vcr do
      result = service.fetch(:api_data, {
        type: 'api',
        params: { url: 'https://api.github.com/users/octocat' }
      })
      
      expect(result).to include('login' => 'octocat')
    end
  end
end
```

## Test Configuration

### Environment Setup
```ruby
# spec/rails_helper.rb
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
```

### Database Configuration
```yaml
# config/database.yml
test:
  <<: *default
  database: <%= Rails.application.class.name.underscore %>_test
  # Use a separate test database for isolation
```

## Factories

Common factory patterns:

```ruby
# Association factories
factory :post do
  author factory: :user
  title { Faker::Lorem.sentence }
  content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
end

# Trait-based factories
factory :user do
  trait :admin do
    admin { true }
  end
  
  trait :with_posts do
    after(:create) do |user|
      create_list(:post, 3, author: user)
    end
  end
end
```

## Continuous Integration

Example GitHub Actions configuration:

```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - name: Setup database
        run: |
          bundle exec rails db:create
          bundle exec rails db:migrate
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
      
      - name: Run tests
        run: bundle exec rspec
```

## Best Practices

- Use factories instead of fixtures
- Mock external services to ensure fast, reliable tests
- Write integration tests for critical user flows
- Use shared examples for common behaviors
- Test both happy path and error conditions
- Maintain test database cleanliness

## Testing

```bash
bin/synth test testing
```

## Version

Current version: 1.0.0