# MCP (Multi-Context Provider) Module

This module provides a flexible context provider system for enriching AI prompts with dynamic data from databases, APIs, files, and other sources.

## Features

- **Multiple Provider Types**: Database queries, HTTP APIs, file parsing, and custom providers
- **Caching System**: Redis-based caching with configurable TTL
- **Authentication Support**: Bearer tokens, API keys, basic auth for external APIs
- **Error Handling**: Graceful error handling with fallbacks
- **Security**: Safe query execution with SQL injection protection

## Installation

```bash
bin/synth add mcp
```

This installs:
- Context provider base classes and implementations
- Database and API providers
- Caching system with Redis
- MCP service for context management

## Post-Installation

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Add routes:**
   ```ruby
   get '/mcp/test', to: 'mcp#test'
   resources :context_providers, only: [:index, :show, :create, :update, :destroy]
   ```

## Usage

### Basic Context Fetching
```ruby
mcp = McpService.new

# Fetch from database
mcp.fetch(:users, {
  type: 'database',
  params: { model: 'User', query_type: 'recent', limit: 10 }
})

# Fetch from API
mcp.fetch(:github_data, {
  type: 'api',
  config: { auth_type: 'bearer', token: 'github_token' },
  params: { url: 'https://api.github.com/user/repos' }
})

# Access context data
context = mcp.to_h
```

### Database Provider
```ruby
# Find specific record
mcp.fetch(:user, {
  type: 'database',
  params: { model: 'User', query_type: 'find', id: 123 }
})

# Custom SQL query
mcp.fetch(:analytics, {
  type: 'database',
  params: { 
    query_type: 'custom',
    sql: 'SELECT COUNT(*) as total FROM users WHERE created_at > ?',
    binds: [1.week.ago]
  }
})
```

### API Provider
```ruby
# GET request with authentication
mcp.fetch(:slack_messages, {
  type: 'api',
  config: {
    auth_type: 'bearer',
    token: Rails.application.credentials.slack.token
  },
  params: {
    url: 'https://slack.com/api/conversations.history',
    query: { channel: 'C1234567890', limit: 50 }
  }
})

# POST request with data
mcp.fetch(:webhook_result, {
  type: 'api',
  params: {
    url: 'https://webhook.site/unique-id',
    method: 'post',
    body: { event: 'user_signup', user_id: current_user.id }.to_json,
    headers: { 'Content-Type' => 'application/json' }
  }
})
```

### Integration with AI Prompts
```ruby
# Build context for AI prompt
mcp = McpService.new
mcp.fetch(:recent_activity, { type: 'database', params: { ... } })
mcp.fetch(:user_preferences, { type: 'api', params: { ... } })

# Use in prompt template
template = PromptTemplate.find_by(name: 'personalized_recommendation')
processor = LlmProcessor.new(template, mcp.to_h)
result = processor.execute
```

## Provider Types

### Database Provider
- Find records by ID
- Query recent records
- Execute custom SQL (SELECT only)
- Count records

### API Provider  
- GET/POST HTTP requests
- Bearer token, API key, basic auth
- JSON and XML response parsing
- Custom headers and query parameters

### Custom Providers
Extend `ContextProviders::BaseProvider` to create custom providers:

```ruby
class CustomProvider < ContextProviders::BaseProvider
  def fetch_data
    # Your custom logic here
    { custom_data: "value" }
  end
end
```

## Caching

- Automatic caching with configurable TTL
- Redis-based storage
- Cache invalidation support
- Per-provider cache keys

## Security

- SQL injection protection for database queries
- Authentication token management
- Rate limiting support
- Error message sanitization

## Testing

```bash
bin/synth test mcp
```

## Version

Current version: 1.0.0