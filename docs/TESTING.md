# Testing Guide

This document outlines testing practices and conventions for the Rails SaaS Starter Template.

## Overview

The template provides comprehensive test coverage using RSpec with the following components:

- **Unit tests** for models, services, and utilities
- **Integration tests** for API endpoints and controllers  
- **System tests** for end-to-end user flows
- **External service mocks** for deterministic testing
- **Factory definitions** for test data generation

## Test Structure

```
spec/
├── factories/          # FactoryBot definitions
├── models/             # Unit tests for models
│   └── ai/            # AI-specific models
├── requests/           # API integration tests
│   └── api/v1/        # JSON:API endpoint tests
├── system/             # End-to-end system tests
├── support/            # Test configuration and helpers
└── rails_helper.rb    # RSpec configuration
```

## Running Tests

### Full Test Suite
```bash
bundle exec rspec
```

### Specific Test Types
```bash
# Unit tests only
bundle exec rspec spec/models

# Integration tests
bundle exec rspec spec/requests

# System tests
bundle exec rspec spec/system

# AI module tests
bin/railsplan test ai

# Authentication tests
bin/railsplan test auth
```

### Test Coverage
```bash
COVERAGE=true bundle exec rspec
open coverage/index.html
```

## Writing Tests

### Model Tests

Follow these patterns for model testing:

```ruby
RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'associations' do
    it { should have_many(:workspaces).through(:memberships) }
  end

  describe 'instance methods' do
    let(:user) { create(:user) }
    
    describe '#full_name' do
      it 'combines first and last name' do
        user.update(first_name: 'John', last_name: 'Doe')
        expect(user.full_name).to eq('John Doe')
      end
    end
  end
end
```

### Request Tests

Test API endpoints using JSON:API helpers:

```ruby
RSpec.describe 'API::V1::Users', type: :request do
  let(:user) { create(:user) }
  
  describe 'GET /api/v1/users/:id' do
    before do
      get "/api/v1/users/#{user.id}", 
          headers: json_api_headers.merge(auth_headers(user))
    end

    it 'returns user data' do
      expect_json_api_resource(
        type: 'users',
        attributes: { email: user.email }
      )
    end
  end
end
```

### System Tests

Test complete user workflows:

```ruby
RSpec.describe 'User Registration', type: :system do
  scenario 'user signs up successfully' do
    visit new_user_registration_path
    
    fill_in 'Email', with: 'test@example.com'
    fill_in 'Password', with: 'password123'
    click_button 'Sign up'
    
    expect(page).to have_content('Welcome!')
  end
end
```

## Factories

Use FactoryBot for test data generation:

```ruby
# Define factories
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    
    trait :admin do
      admin { true }
    end
  end
end

# Use in tests
let(:user) { create(:user) }
let(:admin) { create(:user, :admin) }
let(:users) { create_list(:user, 3) }
```

## External Service Mocking

All external services are automatically mocked in tests:

### OpenAI/Claude APIs
```ruby
# Automatically mocked to return consistent responses
allow_any_instance_of(OpenAI::Client).to receive(:completions)
  .and_return('choices' => [{ 'text' => 'Mocked response' }])
```

### Stripe API
```ruby
# Stripe objects are mocked
allow(Stripe::Customer).to receive(:create)
  .and_return(double('customer', id: 'cus_test123'))
```

### HTTP Requests
```ruby
# WebMock stubs external HTTP calls
stub_request(:get, 'https://api.github.com/user')
  .to_return(status: 200, body: { login: 'testuser' }.to_json)
```

## Test Helpers

### Authentication Helpers
```ruby
# Sign in a user for system tests
sign_in_user

# Create user with workspace
user, workspace = create_user_with_workspace

# Generate auth headers for API tests
headers = auth_headers(user)
```

### JSON:API Helpers
```ruby
# Parse JSON response
json_data
json_errors

# Assert JSON:API responses
expect_json_api_resource(type: 'users', attributes: { email: 'test@example.com' })
expect_json_api_error(status: :not_found, detail: 'User not found')
```

## AI Module Testing

### Prompt Templates
Test prompt rendering and validation:

```ruby
RSpec.describe PromptTemplate do
  describe '#render' do
    let(:template) { create(:prompt_template, content: 'Hello {{name}}!') }
    
    it 'renders with context' do
      result = template.render(name: 'John')
      expect(result).to eq('Hello John!')
    end
  end
end
```

### LLM Jobs
Test asynchronous job execution:

```ruby
RSpec.describe LlmJob do
  describe '#execute!' do
    let(:job) { create(:llm_job, :pending) }
    
    it 'processes job and creates output' do
      expect { job.execute! }.to change { job.llm_outputs.count }.by(1)
      expect(job.reload.status).to eq('completed')
    end
  end
end
```

### MCP Fetchers
Test context fetching and data binding:

```ruby
RSpec.describe McpFetcher do
  describe '#fetch' do
    let(:fetcher) { create(:mcp_fetcher, :http) }
    
    it 'fetches data from external API' do
      result = fetcher.fetch(username: 'testuser')
      expect(result['login']).to eq('testuser')
    end
  end
end
```

## Continuous Integration

The CI pipeline runs:

1. **Linting** - RuboCop, security checks
2. **Unit tests** - Model and service tests
3. **Integration tests** - API endpoint tests  
4. **System tests** - End-to-end workflows
5. **Template test** - Fresh app generation and test run

### CI Configuration

The GitHub Actions workflow tests across:
- Ruby versions: 3.2, 3.3
- PostgreSQL versions: 14, 15, 16
- Template generation and test execution

## Adding New Tests

When extending the template with new modules:

1. **Create factory definitions** in `spec/factories/`
2. **Add model tests** in `spec/models/`
3. **Write integration tests** for APIs in `spec/requests/`
4. **Create system tests** for user flows in `spec/system/`
5. **Update CLI test command** to include new module
6. **Mock external services** in `spec/support/external_service_mocks.rb`

## Best Practices

### Do
- Write tests for all new features
- Use factories instead of fixtures
- Mock external service calls
- Test both happy and error paths
- Keep tests focused and readable
- Use descriptive test names

### Don't
- Make real API calls in tests
- Use hardcoded data in tests
- Write overly complex test setup
- Test Rails framework functionality
- Skip edge case testing

## Debugging Tests

### Common Issues

1. **Flaky tests** - Usually caused by unmocked external calls
2. **Slow tests** - Often due to missing database cleanup
3. **Failing CI** - Check for environment-specific dependencies

### Debug Commands
```bash
# Run specific test with full output
bundle exec rspec spec/models/user_spec.rb:15 --format documentation

# Debug with binding.pry
# Add `binding.pry` in test and run with:
bundle exec rspec spec/models/user_spec.rb:15

# Check test coverage
COVERAGE=true bundle exec rspec
```

This comprehensive testing approach ensures the generated Rails application is reliable, maintainable, and thoroughly tested from day one.