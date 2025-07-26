# MCP (Multi-Context Provider) Fetcher Integration

This implementation provides a complete MCP fetcher system integrated with the LLMJob pipeline, enabling dynamic context enrichment for AI prompts.

## Features

✅ **LLMJob Integration**: Seamless integration with the existing LLM processing pipeline  
✅ **Specialized Fetchers**: Ready-to-use fetchers for common use cases  
✅ **External API Support**: GitHub API integration with token authentication  
✅ **Document Processing**: Text analysis, summarization, and keyword extraction  
✅ **Database Queries**: Smart ActiveRecord query building with user/workspace scoping  
✅ **Error Handling**: Graceful fallbacks when fetchers fail  
✅ **Comprehensive Testing**: Unit and integration tests with mocking  
✅ **Caching Support**: Redis-based caching with configurable TTL  

## Quick Start

### Basic Usage

```ruby
# Simple order context enrichment
LLMJob.perform_later(
  template: "Hello {{user_name}}, you have {{count}} recent orders totaling ${{summary_total_value}}.",
  model: 'gpt-4',
  context: { user_name: user.name },
  user_id: user.id,
  mcp_fetchers: [
    { key: :recent_orders, params: { limit: 5 } }
  ]
)
```

### Multi-Source Context

```ruby
# Customer support with GitHub profile
LLMJob.perform_later(
  template: """
    Support for {{user_name}}:
    - Orders: {{count}} recent orders
    - Developer: {{profile_name}} ({{profile_public_repos}} repos)
    - Issue: {{issue_description}}
  """,
  model: 'gpt-4',
  context: { 
    user_name: user.name,
    issue_description: "API integration help needed"
  },
  user_id: user.id,
  mcp_fetchers: [
    { key: :recent_orders, params: { limit: 10 } },
    { 
      key: :github_info, 
      params: { 
        username: user.github_username,
        github_token: ENV['GITHUB_TOKEN']
      }
    }
  ]
)
```

## Available Fetchers

### Database Fetchers
- `:database` - Generic ActiveRecord queries
- `:recent_orders` - E-commerce order data with summaries
- `:user_activity` - User activity tracking

### HTTP Fetchers  
- `:http` - Generic HTTP API calls
- `:github_info` - GitHub profile and repository data
- `:github_repo` - Individual repository information
- `:slack_messages` - Slack API integration

### File Fetchers
- `:file` - Generic file processing
- `:document_summary` - Document analysis and summarization
- `:parse_document` - Document parsing
- `:extract_text` - Text extraction

### Semantic Fetchers
- `:semantic_memory` - Embedding-based retrieval
- `:semantic_search` - Similarity search
- `:find_similar` - Find similar content

### Code Fetchers
- `:code` - Codebase introspection
- `:find_methods` - Method discovery
- `:search_code` - Code search

## Specialized Fetcher Examples

### Recent Orders Fetcher

```ruby
# Fetch recent orders with detailed analysis
{
  key: :recent_orders,
  params: {
    limit: 10,
    since: 3.months.ago,
    status: 'completed',
    include_details: true  # Adds formatted currency, days_ago, etc.
  }
}

# Returns:
{
  model: 'Order',
  count: 5,
  records: [...],
  summary: {
    total_value: 1247.50,
    average_value: 249.50,
    statuses: { 'completed' => 4, 'pending' => 1 }
  }
}
```

### GitHub Info Fetcher

```ruby
# Fetch GitHub profile and repositories
{
  key: :github_info,
  params: {
    username: 'octocat',
    github_token: ENV['GITHUB_TOKEN'],  # Optional but recommended
    include_repos: true,
    repo_limit: 10,
    org_name: 'github'  # For organization repos
  }
}

# Returns:
{
  username: 'octocat',
  success: true,
  profile: {
    name: 'The Octocat',
    bio: 'GitHub mascot',
    public_repos: 8,
    followers: 4000
  },
  repositories: {
    count: 8,
    repositories: [...],
    summary: {
      total_stars: 15000,
      languages: { 'Ruby' => 3, 'JavaScript' => 2 }
    }
  }
}
```

### Document Summary Fetcher

```ruby
# Analyze uploaded documents
{
  key: :document_summary,
  params: {
    file_path: '/path/to/document.pdf',
    # OR
    file_content: uploaded_file.read,
    file_type: 'application/pdf',
    max_summary_length: 500,
    extract_keywords: true,
    include_metadata: true,
    chunk_size: 1000
  }
}

# Returns:
{
  success: true,
  file_type: 'application/pdf',
  summary: 'Document discusses...',
  keywords: ['technology', 'automation', 'analysis'],
  metadata: {
    word_count: 1247,
    reading_time_minutes: 6,
    language: 'en'
  },
  chunks: [...]
}
```

## Error Handling

The MCP system includes robust error handling:

```ruby
# Individual fetcher failures don't break the job
mcp_fetchers = [
  { key: :recent_orders, params: { limit: 5 } },    # ✅ Succeeds
  { key: :github_info, params: { username: 'bad' } } # ❌ Fails (404)
]

# Job continues with partial data
result = LLMJob.perform_now(
  template: "Orders: {{count}}, GitHub: {{profile_name}}",
  model: 'gpt-4',
  context: { user_name: "Alice" },
  mcp_fetchers: mcp_fetchers
)

# Result includes successful data only
# Template becomes: "Orders: 5, GitHub: {{profile_name}}"
```

## Configuration

### Environment Variables

```bash
# GitHub API (recommended for higher rate limits)
GITHUB_TOKEN=ghp_your_token_here

# Redis for caching (optional but recommended)
REDIS_URL=redis://localhost:6379/0

# Rate limiting (optional)
MCP_HTTP_RATE_LIMIT=100  # requests per hour
```

### Custom Fetcher Registration

```ruby
# Create custom fetcher
class WeatherFetcher < Mcp::Fetcher::Base
  def self.allowed_params
    [:location, :units]
  end

  def self.required_param?(param)
    param == :location
  end

  def self.fetch(location:, units: 'metric', **)
    # Your implementation
    { temperature: 22, condition: 'sunny' }
  end

  def self.description
    "Fetches weather data"
  end
end

# Register it
Mcp::Registry.register(:weather, WeatherFetcher)

# Use it
context.fetch(:weather, location: 'San Francisco')
```

## Testing

Run the test suite:

```bash
# Test individual fetchers
ruby -Itest app/domains/ai/test/services/mcp/fetcher/recent_orders_test.rb

# Test LLMJob integration
ruby -Itest app/domains/ai/test/jobs/llm_job_test.rb

# Integration tests
ruby -Itest app/domains/ai/test/integration/mcp_llm_integration_test.rb
```

## Performance Considerations

### Caching Strategy
- HTTP responses cached for 30 minutes - 1 hour
- Database queries cached for 5-15 minutes
- Document processing cached for 24 hours

### Rate Limiting
- GitHub API: 5000 requests/hour (authenticated), 60/hour (unauthenticated)
- Custom HTTP fetchers respect rate limits per domain
- Automatic exponential backoff on failures

### Resource Usage
- Document processing: Memory usage proportional to file size
- Large documents automatically chunked for processing
- HTTP timeouts prevent hanging requests

## Troubleshooting

### Common Issues

**GitHub API Rate Limiting**
```ruby
# Solution: Set GITHUB_TOKEN environment variable
ENV['GITHUB_TOKEN'] = 'your_token_here'
```

**Order Model Not Found**
```ruby
# The RecentOrders fetcher gracefully handles missing models
# Check that your Order model exists and has the expected columns:
# - user_id, workspace_id, total, status, created_at
```

**Document Processing Fails**
```ruby
# Ensure file permissions and disk space
# For PDF processing, consider adding pdf-reader gem
```

**Cache Not Working**
```ruby
# Verify Redis connection
Rails.cache.write('test', 'value')
Rails.cache.read('test') # Should return 'value'
```

## Security Considerations

- **API Tokens**: Store in Rails credentials or environment variables
- **SQL Injection**: Database fetcher uses parameterized queries
- **File Processing**: Validates file types and sizes
- **Rate Limiting**: Prevents API abuse
- **Error Messages**: Sanitized to prevent information leakage

## Advanced Usage

### Direct MCP Context Usage

```ruby
# For more control, use MCP Context directly
context = Mcp::Context.new(user: current_user)

# Add multiple data sources
context.fetch(:recent_orders, limit: 5)
context.fetch(:github_info, username: current_user.github_username)

# Check for errors
if context.has_errors?
  Rails.logger.warn("MCP errors: #{context.error_keys}")
end

# Get enriched data
enriched_data = context.to_h

# Use with LLMJob
LLMJob.perform_later(
  template: template,
  model: 'gpt-4',
  context: enriched_data
)
```

### Template Integration

The system supports various template formats:

```ruby
# Mustache-style (recommended)
"Hello {{user_name}}, you have {{count}} orders"

# Conditional sections
"""
{{#profile}}
GitHub: {{profile_name}}
{{/profile}}
{{^profile}}
No GitHub profile found
{{/profile}}
"""

# Nested data access
"Language: {{repositories_summary_languages_Ruby}}"
```

This implementation provides a production-ready MCP fetcher system that seamlessly integrates with the existing LLMJob pipeline while maintaining backwards compatibility and providing extensive error handling and testing coverage.