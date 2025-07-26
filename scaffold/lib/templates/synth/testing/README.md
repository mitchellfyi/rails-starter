# Testing Module

Provides comprehensive test coverage for the Rails SaaS Starter Template using RSpec.

## Features

- **RSpec configuration** with proper setup for Rails applications
- **Factory definitions** for all core models (User, Workspace, Membership)
- **External service mocks** for OpenAI, Claude, Stripe, GitHub APIs
- **Test helpers** for authentication, JSON:API testing, and system tests
- **Database cleaner** setup for proper test isolation
- **Capybara configuration** for system/integration tests

## Installation

This module is automatically installed with the template. To manually install:

```sh
bin/synth add testing
```

## Usage

Run the full test suite:

```sh
bundle exec rspec
```

Run specific test types:

```sh
# Unit tests only
bundle exec rspec spec/models

# Integration tests
bundle exec rspec spec/requests

# System tests
bundle exec rspec spec/system
```

## Test Structure

- `spec/models/` - Unit tests for models, validations, associations
- `spec/requests/` - API endpoint tests with JSON:API validation
- `spec/system/` - End-to-end user flow tests with Capybara
- `spec/factories/` - Factory definitions for test data
- `spec/support/` - Test configuration and helpers

## Writing Tests

### Model Tests

```ruby
RSpec.describe User, type: :model do
  it { should validate_presence_of(:email) }
  it { should have_many(:memberships) }
  
  describe '#admin?' do
    it 'returns true for admin users' do
      user = create(:user, :admin)
      expect(user.admin?).to be true
    end
  end
end
```

### Request Tests

```ruby
RSpec.describe 'API::V1::Users', type: :request do
  let(:user) { create(:user) }
  
  describe 'GET /api/v1/users/:id' do
    before { get "/api/v1/users/#{user.id}", headers: json_api_headers }
    
    it 'returns user data' do
      expect_json_api_resource(type: 'users', attributes: { email: user.email })
    end
  end
end
```

### System Tests

```ruby
RSpec.describe 'User Authentication', type: :system do
  scenario 'user signs up successfully' do
    visit new_user_registration_path
    fill_in 'Email', with: 'test@example.com'
    fill_in 'Password', with: 'password123'
    click_button 'Sign up'
    
    expect(page).to have_content('Welcome!')
  end
end
```

## External Service Mocking

All external services are automatically mocked in tests:

- **OpenAI/Claude**: Returns predefined responses
- **Stripe**: Returns mock customer/subscription objects  
- **GitHub**: Returns mock user data
- **HTTP requests**: Stubbed to return JSON responses

This ensures tests run offline and deterministically.