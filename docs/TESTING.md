# Testing Strategy

This document outlines the comprehensive testing approach for the Rails SaaS Starter Template and its modules.

## Testing Framework

The template supports both **RSpec** and **Minitest**. Choose your preferred framework during setup:

```bash
# RSpec (recommended)
gem 'rspec-rails', group: [:development, :test]

# Minitest (Rails default)
# Already included with Rails
```

## Test Structure

### Core Application Tests
- **Unit Tests**: Models, services, helpers, and utilities
- **Integration Tests**: Controllers, API endpoints, and business workflows  
- **System Tests**: End-to-end user flows with browser automation
- **Component Tests**: UI components and JavaScript functionality

### Module-Specific Tests
Each module includes its own test suite:
```
lib/templates/synth/ai/
├── spec/               # RSpec tests
│   ├── models/
│   ├── jobs/
│   ├── services/
│   └── system/
├── test/               # Minitest tests (alternative)
└── README.md
```

## Running Tests

### Full Test Suite
```bash
# RSpec
bundle exec rspec

# Minitest
bin/rails test

# Via Synth CLI
bin/synth test
```

### Module-Specific Tests
```bash
# Test specific module
bin/synth test ai
bin/synth test billing
bin/synth test cms

# Test specific file
bundle exec rspec spec/models/prompt_template_spec.rb
bin/rails test test/models/workspace_test.rb
```

### Test Categories
```bash
# Unit tests only
bundle exec rspec spec/models spec/services
bin/rails test test/models test/services

# Integration tests
bundle exec rspec spec/requests
bin/rails test test/integration

# System tests (browser automation)
bundle exec rspec spec/system
bin/rails test:system
```

## Test Configuration

### Environment Setup
```ruby
# config/environments/test.rb
config.cache_classes = true
config.eager_load = false
config.serve_static_files = true
config.static_cache_control = "public, max-age=3600"

# Disable request forgery protection in test environment
config.action_controller.allow_forgery_protection = false

# Test adapter for Active Job
config.active_job.queue_adapter = :test

# Disable action mailer delivery
config.action_mailer.delivery_method = :test
```

### Database Configuration
```yaml
# config/database.yml
test:
  adapter: postgresql
  encoding: unicode
  database: myapp_test
  pool: 5
  username: <%= ENV.fetch("DATABASE_USERNAME", "postgres") %>
  password: <%= ENV.fetch("DATABASE_PASSWORD", "") %>
  host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>
```

## Mocking External Services

### API Mocking Strategy
All external services are mocked to ensure:
- Deterministic test results
- Fast test execution
- No dependency on external services
- Cost-effective testing (no API charges)

### Common Service Mocks

**OpenAI API:**
```ruby
# spec/support/openai_mock.rb
RSpec.configure do |config|
  config.before(:each) do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [{ message: { content: "Mocked response" } }]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
```

**Stripe API:**
```ruby
# spec/support/stripe_mock.rb
require 'stripe_mock'

RSpec.configure do |config|
  config.before(:each) { StripeMock.start }
  config.after(:each) { StripeMock.stop }
end
```

**Background Jobs:**
```ruby
# Clear job queue between tests
RSpec.configure do |config|
  config.before(:each) do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end
end
```

## Continuous Integration

### GitHub Actions Workflow
```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:7
        ports:
          - 6379:6379
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true
      
      - name: Set up database
        run: |
          bin/rails db:create db:migrate
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/myapp_test
      
      - name: Run tests
        run: bundle exec rspec
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/myapp_test
          REDIS_URL: redis://localhost:6379/0
```

## Running CI Locally

### Using Docker Compose
```yaml
# docker-compose.test.yml
version: '3.8'
services:
  app:
    build: .
    command: bundle exec rspec
    volumes:
      - .:/app
    environment:
      - DATABASE_URL=postgres://postgres:password@db:5432/myapp_test
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
  
  db:
    image: pgvector/pgvector:pg16
    environment:
      - POSTGRES_PASSWORD=password
  
  redis:
    image: redis:7
```

```bash
# Run tests in Docker
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit
```

### Using Local Services
```bash
# Start services
brew services start postgresql
brew services start redis

# Setup test database
createdb myapp_test
bin/rails db:test:prepare

# Run tests
bundle exec rspec
```

## Test Data Management

### Factories
```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }
    confirmed_at { Time.current }
  end
end
```

### Test Seeds
```ruby
# db/seeds/test.rb
if Rails.env.test?
  # Create test data that all tests can rely on
  test_user = User.create!(
    email: "test@example.com",
    password: "password123"
  )
end
```

## Performance Testing

### Load Testing
```ruby
# spec/performance/load_spec.rb
RSpec.describe "API Performance", type: :request do
  it "handles concurrent requests" do
    threads = 10.times.map do
      Thread.new do
        get "/api/v1/prompt_templates"
        expect(response).to have_http_status(:ok)
      end
    end
    
    threads.each(&:join)
  end
end
```

### Memory Testing
```bash
# Use memory_profiler gem
gem 'memory_profiler', group: :test

# Profile memory usage
report = MemoryProfiler.report do
  # Your code here
end

report.pretty_print
```

## Test Coverage

### SimpleCov Configuration
```ruby
# spec/spec_helper.rb
require 'simplecov'

SimpleCov.start 'rails' do
  add_filter '/vendor/'
  add_filter '/spec/'
  
  minimum_coverage 90
end
```

### Coverage Reports
```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# View report
open coverage/index.html
```

## Best Practices

### Test Organization
1. **Arrange, Act, Assert** pattern for clear test structure
2. **One assertion per test** for focused testing
3. **Descriptive test names** that explain the behavior being tested
4. **Shared examples** for common behavior across modules

### Mock Guidelines
1. **Mock at the boundary** - external services only
2. **Verify behavior, not implementation** 
3. **Use real objects** for internal application code
4. **Keep mocks simple** and close to real API responses

### Performance Guidelines
1. **Parallel execution** for faster test runs
2. **Database cleanup** between tests using DatabaseCleaner
3. **Minimal test data** - create only what you need
4. **Selective testing** during development using focus/tags

## Troubleshooting Tests

### Common Issues

**Database connection errors:**
```bash
# Reset test database
bin/rails db:test:prepare
```

**Flaky system tests:**
```ruby
# Increase wait times for CI
Capybara.default_max_wait_time = 10
```

**Memory issues:**
```bash
# Increase test timeout
export RSPEC_TIMEOUT=300
```

**Stuck background jobs:**
```ruby
# Clear job queues
ActiveJob::Base.queue_adapter.enqueued_jobs.clear
ActiveJob::Base.queue_adapter.performed_jobs.clear
```

## Contributing Tests

When adding new features:

1. **Write tests first** (TDD approach)
2. **Test happy path and edge cases**
3. **Include integration tests** for user-facing features
4. **Add system tests** for critical user flows
5. **Update test documentation** for new patterns

For more information, see the main [contributing guide](../AGENTS.md).