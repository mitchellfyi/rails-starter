# AI Module

This module adds first‑class AI integration to your Rails app. It installs prompt templates, an LLM job runner, and the MCP (Multi‑Context Provider) system for enriching prompts with dynamic data.

## Installation

Run the following command from your application root to install the AI module via the Synth CLI:

```bash
bin/synth add ai
```

This command will:
- Add necessary gems (`ruby-openai`, `pgvector`)
- Install the MCP (Multi-Context Provider) system
- Create vector embeddings table for semantic search
- Copy configuration files and initializers
- Set up comprehensive test coverage

After installation, run the database migration:

```bash
rails db:migrate
```

## MCP (Multi-Context Provider) System

The MCP system allows you to enrich AI prompts with dynamic data from various sources. It provides a unified interface for fetching context data that can be used in LLM prompts.

### Core Components

#### 1. Registry (`Mcp::Registry`)
Central registry for managing fetchers:

```ruby
# Register a custom fetcher
Mcp::Registry.register(:my_fetcher, MyCustomFetcher)

# Check what's registered
Mcp::Registry.keys  # => [:database, :http, :file, :semantic_memory, :code, ...]

# Get a fetcher
fetcher = Mcp::Registry.get(:database)
```

#### 2. Context API (`Mcp::Context`)
Main interface for fetching and combining data:

```ruby
# Initialize with base context
context = Mcp::Context.new(user: current_user, workspace: current_workspace)

# Fetch data from various sources
context.fetch(:recent_orders, model: 'Order', scope: :recent, limit: 5)
context.fetch(:github_repo, url: 'https://api.github.com/repos/rails/rails')
context.fetch(:semantic_search, query: "How to implement authentication?")

# Get combined context for prompts
prompt_data = context.to_h
# => { user: #<User>, workspace: #<Workspace>, recent_orders: [...], github_repo: {...}, semantic_search: [...] }

# Check for errors
if context.has_errors?
  puts "Errors: #{context.error_keys}"
end
```

### Built-in Fetchers

#### 1. Database Fetcher (`Mcp::Fetcher::Database`)
Fetch data using ActiveRecord queries and scopes:

```ruby
# Fetch recent orders for current user
context.fetch(:recent_orders,
  model: 'Order',
  scope: :recent,
  scope_args: [1.week.ago],
  user: current_user,
  limit: 10
)

# Fetch with custom conditions
context.fetch(:active_subscriptions,
  model: 'Subscription',
  conditions: { status: 'active' },
  order: 'created_at DESC'
)
```

#### 2. HTTP Fetcher (`Mcp::Fetcher::Http`)
Make requests to external APIs with caching and rate limiting:

```ruby
# Fetch GitHub repository info
context.fetch(:github_repo,
  url: 'https://api.github.com/repos/rails/rails',
  headers: { 'Authorization' => "token #{github_token}" },
  cache_key: 'github_rails_repo',
  cache_ttl: 1.hour
)

# Fetch Slack messages
context.fetch(:slack_messages,
  url: 'https://slack.com/api/conversations.history',
  params: { channel: 'C1234567890' },
  headers: { 'Authorization' => "Bearer #{slack_token}" },
  rate_limit_key: 'slack_api'
)
```

#### 3. File Fetcher (`Mcp::Fetcher::File`)
Parse documents and create text embeddings:

```ruby
# Parse uploaded document
context.fetch(:parse_document,
  file_path: '/path/to/document.pdf',
  chunk_size: 1000,
  create_embeddings: true,
  extract_metadata: true
)

# Parse text content directly
context.fetch(:extract_text,
  file_content: uploaded_file.read,
  file_type: 'markdown',
  chunk_size: 500
)
```

#### 4. Semantic Memory Fetcher (`Mcp::Fetcher::SemanticMemory`)
Query vector embeddings for contextually relevant content:

```ruby
# Semantic search
context.fetch(:semantic_search,
  query: "How to implement user authentication?",
  limit: 5,
  threshold: 0.8,
  namespace: 'documentation'
)

# Search with metadata filters
context.fetch(:find_similar,
  query: "payment processing",
  metadata_filter: { category: 'billing', status: 'published' },
  content_types: ['tutorial', 'documentation']
)
```

#### 5. Code Fetcher (`Mcp::Fetcher::Code`)
Introspect your codebase to find methods, classes, and comments:

```ruby
# Find method definitions
context.fetch(:find_methods,
  search_term: "authenticate",
  search_type: :method_name,
  include_comments: true,
  max_results: 10
)

# Search code content
context.fetch(:search_code,
  search_term: "Stripe",
  search_type: :content,
  file_pattern: "**/*.rb",
  exclude_paths: ['vendor', 'tmp']
)
```

### Creating Custom Fetchers

Create your own fetchers by extending the base class:

```ruby
class WeatherFetcher < Mcp::Fetcher::Base
  def self.allowed_params
    [:location, :api_key]
  end

  def self.required_param?(param)
    param == :location
  end

  def self.description
    "Fetches current weather data from external API"
  end

  def self.fetch(location:, api_key: nil, **)
    validate_all_params!(location: location, api_key: api_key)
    
    # Your fetching logic here
    response = external_weather_api(location, api_key)
    
    {
      location: location,
      temperature: response['temp'],
      conditions: response['weather'],
      fetched_at: Time.current
    }
  end

  def self.fallback_data(location: nil, **)
    {
      location: location,
      temperature: nil,
      conditions: 'unknown',
      error: 'Weather data unavailable'
    }
  end

  private

  def self.external_weather_api(location, api_key)
    # Implementation details...
  end
end

# Register your custom fetcher
Mcp::Registry.register(:weather, WeatherFetcher)

# Use it in context
context.fetch(:weather, location: 'San Francisco')
```

### Error Handling and Fallbacks

The MCP system provides robust error handling:

```ruby
context = Mcp::Context.new(user: current_user)

# This fetcher might fail
context.fetch(:external_api_data, url: 'https://unreliable-api.com/data')

# Check for success/failure
if context.success?(:external_api_data)
  data = context[:external_api_data]
else
  error_msg = context.error_message(:external_api_data)
  Rails.logger.warn("API fetch failed: #{error_msg}")
end

# Fetchers can provide fallback data
# If a fetcher implements `fallback_data`, it will be used when fetch fails
```

### Testing

Test your MCP usage with RSpec:

```ruby
RSpec.describe "MCP Integration" do
  before do
    # Register test fetcher
    test_fetcher = Class.new(Mcp::Fetcher::Base) do
      def self.fetch(**params)
        { test_data: "success", params: params }
      end
    end
    
    Mcp::Registry.register(:test_fetcher, test_fetcher)
  end

  it "fetches context data" do
    context = Mcp::Context.new(user: create(:user))
    context.fetch(:test_fetcher, param1: 'value1')
    
    expect(context.success?(:test_fetcher)).to be true
    expect(context[:test_fetcher][:test_data]).to eq('success')
  end
end
```

### Configuration

Configure the AI module in `config/initializers/ai.rb`:

```ruby
Rails.application.config.ai.default_model = 'gpt-4'
Rails.application.config.ai.embedding_model = 'text-embedding-ada-002'

# Configure OpenAI client
OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.openai_api_key
end
```

Set your API keys in Rails credentials:

```bash
rails credentials:edit
```

```yaml
openai_api_key: your_openai_api_key_here
github_token: your_github_token_here
slack_token: your_slack_token_here
```

## Next Steps

After installation:

1. Configure your API keys in Rails credentials
2. Run the test suite to ensure everything works:
   ```bash
   bin/synth test ai
   ```
3. Customize fetchers for your specific use case
4. Integrate MCP context into your LLM prompts

## Contributing

Contributions and improvements are welcome. Keep this README up to date as the module evolves.
