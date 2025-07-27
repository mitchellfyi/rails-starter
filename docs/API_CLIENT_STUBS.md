# API Client Stubs for Testing

This document describes the API client stub system that provides fake clients for external APIs during testing.

## Overview

The Rails SaaS Starter Template includes a comprehensive stub system for external API clients that automatically activates in test environments. This ensures deterministic, fast, and reliable tests without making actual API calls.

## Supported APIs

- **OpenAI/LLM APIs** - Chat completions, text completions, embeddings, models
- **GitHub API** - User profiles, repositories, organizations
- **Stripe API** - Customers, subscriptions, payment methods, invoices
- **Generic HTTP APIs** - Any REST API with customizable responses

## Usage

### Automatic Activation

The stub system automatically activates when `Rails.env.test?` returns `true`. No configuration needed:

```ruby
# In test environment, this returns a stub client
client = ApiClientFactory.openai_client
response = client.completions(messages: [{ role: 'user', content: 'Hello' }])
# Returns deterministic response every time
```

### Factory Pattern

All clients are accessed through `ApiClientFactory`:

```ruby
# Get appropriate client for environment
openai_client = ApiClientFactory.openai_client    # OpenAI/LLM API
github_client = ApiClientFactory.github_client    # GitHub API  
stripe_client = ApiClientFactory.stripe_client    # Stripe API
http_client = ApiClientFactory.http_client        # Generic HTTP

# Check if running in stub mode
ApiClientFactory.stub_mode? # => true in test environment
```

## Stub Client Features

### Deterministic Responses

All stub clients return the same response for the same input:

```ruby
client = ApiClientFactory.openai_client

# These will return identical responses
response1 = client.completions(messages: [{ role: 'user', content: 'Hello' }])
response2 = client.completions(messages: [{ role: 'user', content: 'Hello' }])

assert_equal response1, response2
```

### Realistic Data Structure

Stub responses match the structure of real API responses:

```ruby
# OpenAI response structure
{
  'id' => 'chatcmpl-stub123',
  'object' => 'chat.completion',
  'created' => 1677649963,
  'model' => 'gpt-4',
  'choices' => [{
    'index' => 0,
    'message' => {
      'role' => 'assistant',
      'content' => 'Deterministic response...'
    },
    'finish_reason' => 'stop'
  }],
  'usage' => { ... }
}
```

### Format-Aware Responses

OpenAI stub detects content patterns and returns appropriate formats:

```ruby
# Request for JSON returns JSON-formatted response
json_response = client.completions(
  messages: [{ role: 'user', content: 'Return JSON data' }]
)
# Response starts with '{' and contains JSON

# Request for markdown returns markdown-formatted response  
md_response = client.completions(
  messages: [{ role: 'user', content: 'Return markdown format' }]
)
# Response starts with '# ' and contains markdown
```

## Integration with Existing Code

### LLM Jobs

The `LLMJob` automatically uses stub clients in test environment:

```ruby
# This will use OpenAI stub in tests
output = LLMJob.perform_now(
  template: "Hello {{name}}",
  model: "gpt-4", 
  context: { name: "Alice" },
  format: "text"
)

# Response is deterministic and fast
assert_includes output.raw_response, "Alice"
```

### MCP Fetchers

MCP fetchers (GitHub, HTTP) automatically use stubs:

```ruby
# Uses GitHub stub in test environment
result = Mcp::Fetcher::GitHubInfo.fetch(
  username: 'octocat',
  include_repos: true,
  repo_limit: 5
)

assert result[:success]
assert_equal 'octocat', result[:username]
assert_equal 5, result[:repositories][:count]
```

### Billing Operations

Enhanced billing stubs provide comprehensive Stripe API coverage:

```ruby
# Create test customer
customer = ApiClientFactory.stripe_client.customer.create(
  email: 'test@example.com',
  name: 'Test Customer'
)

# Create test subscription
subscription = ApiClientFactory.stripe_client.subscription.create(
  customer: customer['id'],
  items: [{ price: 'price_test123' }]
)

assert subscription['status'].in?(['active', 'trialing'])
```

## Error Simulation

All stub clients support error simulation for testing error handling:

```ruby
# Simulate different types of errors
client.simulate_error(:rate_limit)      # Rate limit exceeded
client.simulate_error(:invalid_api_key) # Authentication error
client.simulate_error(:service_unavailable) # Service down
```

## HTTP Client Features

The HTTP stub client provides additional testing utilities:

```ruby
http_client = ApiClientFactory.http_client

# Register custom mock responses
http_client.register_mock(
  'api.example.com',
  { status: 200, data: { message: 'Custom response' } }
)

# Track request history
http_client.get('https://api.example.com/test')
assert http_client.requested?('api.example.com/test')
assert_equal 1, http_client.request_count('api.example.com')

# Clear history and mocks
http_client.clear_mocks
```

## Testing the Stubs

Run the integration test to verify stub functionality:

```bash
ruby test/api_stubs_integration_test.rb
```

Run AI domain-specific stub tests:

```bash
# From AI domain
ruby test/integration/api_client_stubs_test.rb
```

## Writing Tests with Stubs

### Basic Testing

```ruby
class MyFeatureTest < ActiveSupport::TestCase
  test "feature uses AI correctly" do
    # Stubs are automatically active in test environment
    result = MyService.call_ai_for_analysis(text: "analyze this")
    
    # Response is deterministic
    assert result.success?
    assert_includes result.response, "analysis"
  end
end
```

### Testing Error Scenarios

```ruby
test "handles AI API failures gracefully" do
  # Simulate API failure
  client = ApiClientFactory.openai_client
  client.stubs(:completions).raises(StandardError, "API Error")
  
  # Verify graceful error handling
  result = MyService.call_ai_for_analysis(text: "test")
  assert result.failure?
  assert_includes result.error_message, "API Error"
end
```

### Testing GitHub Integration

```ruby
test "fetches user repositories correctly" do
  # Uses GitHub stub automatically
  result = MyService.fetch_user_repos(username: 'developer')
  
  assert result.success?
  assert result.repos.length > 0
  assert result.repos.first.key?('name')
  assert result.repos.first.key?('language')
end
```

## Configuration

### Custom Responses

For specific test scenarios, you can register custom HTTP responses:

```ruby
# In test setup
http_client = ApiClientFactory.http_client
http_client.register_mock(
  /special-api\.com/,
  { 
    status: 200,
    data: { special_data: "custom response for this test" }
  }
)
```

### Environment Detection

The factory detects test environment via `Rails.env.test?`. For custom environments:

```ruby
# Force stub mode (useful for development testing)
Rails.env.stubs(:test?).returns(true)

# Or check current mode
if ApiClientFactory.stub_mode?
  puts "Using stub clients"
else
  puts "Using real clients"
end
```

## Benefits

1. **Fast Tests** - No network calls, tests run quickly
2. **Deterministic** - Same input always produces same output
3. **Reliable** - No flaky tests due to network issues or API changes
4. **Comprehensive** - Covers all major external APIs used in the application
5. **Error Testing** - Easy simulation of various error conditions
6. **Zero Configuration** - Works automatically in test environment

## Files

- `lib/api_client_factory.rb` - Main factory for client selection
- `lib/stubs/openai_client_stub.rb` - OpenAI/LLM API stub
- `lib/stubs/github_client_stub.rb` - GitHub API stub  
- `lib/stubs/stripe_client_stub.rb` - Stripe API stub
- `lib/stubs/http_client_stub.rb` - Generic HTTP API stub
- `test/api_stubs_integration_test.rb` - Integration tests
- `app/domains/ai/test/integration/api_client_stubs_test.rb` - AI-specific tests