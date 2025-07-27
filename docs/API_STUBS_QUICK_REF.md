# API Client Stubs - Quick Reference

## Overview
The Rails SaaS Starter includes comprehensive API client stubs that automatically activate in test environments, providing deterministic responses for external APIs.

## Automatic Activation
```ruby
# Automatically uses stubs in test environment
Rails.env.test? # => true
ApiClientFactory.stub_mode? # => true

# Get stub clients
openai_client = ApiClientFactory.openai_client
github_client = ApiClientFactory.github_client  
stripe_client = ApiClientFactory.stripe_client
http_client = ApiClientFactory.http_client
```

## Supported APIs
- **OpenAI/LLM** - Chat completions, embeddings, models
- **GitHub** - Users, repositories, organizations  
- **Stripe** - Customers, subscriptions, payments
- **HTTP** - Generic REST APIs with custom responses

## Key Features
- ✅ **Deterministic** - Same input = same output
- ✅ **Fast** - No network calls in tests
- ✅ **Realistic** - Matches real API response structure
- ✅ **Error Simulation** - Test failure scenarios
- ✅ **Zero Config** - Works automatically in tests

## Quick Examples

### LLM/AI Testing
```ruby
# Uses OpenAI stub automatically
output = LLMJob.perform_now(
  template: "Hello {{name}}", 
  model: "gpt-4",
  context: { name: "Alice" }
)
# Returns deterministic response every time
```

### GitHub Integration
```ruby
# Uses GitHub stub automatically  
result = Mcp::Fetcher::GitHubInfo.fetch(
  username: 'octocat',
  include_repos: true
)
# Returns consistent user and repo data
```

### Billing/Stripe
```ruby
# Uses Stripe stub automatically
customer = stripe_client.customer.create(
  email: 'test@example.com'
)
# Returns realistic customer object
```

### Error Testing
```ruby
client.simulate_error(:rate_limit)
client.simulate_error(:service_unavailable)
```

## Documentation
- Full guide: `docs/API_CLIENT_STUBS.md`
- Integration tests: `test/api_stubs_integration_test.rb`
- AI tests: `app/domains/ai/test/integration/api_client_stubs_test.rb`