# AI Module

This module adds comprehensive AI integration to your Rails application, including prompt templates, asynchronous LLM job processing, and a multi‑context provider (MCP) system for enriching prompts with dynamic data.

## Features

- **Prompt Templates**: Store and version prompts with variable interpolation, tags, and multiple output formats (JSON, Markdown, HTML)
- **LLM Job System**: Asynchronous job processing with Sidekiq for OpenAI, Claude, and other providers
- **Multi-Context Provider (MCP)**: Dynamically fetch context from databases, APIs, files, and semantic memory
- **User Feedback**: Thumbs up/down feedback system for LLM outputs
- **Retry Logic**: Exponential backoff for failed LLM requests
- **Audit Logging**: Complete input/output logging for debugging and improvement

## Installation

Add the AI module to your Rails application:

```bash
bin/synth add ai
```

This command will:
- Add required gems (`ruby-openai`, etc.) to your Gemfile
- Run database migrations for prompt templates and LLM outputs
- Create initializers and configuration files
- Set up routes and controllers
- Install comprehensive tests

## Configuration

After installation, configure your LLM providers:

```ruby
# config/credentials.yml.enc
openai:
  api_key: your_openai_api_key

anthropic:
  api_key: your_anthropic_api_key
```

Or using environment variables:
```bash
# .env
OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
```

## Usage

### Creating Prompt Templates

```ruby
template = PromptTemplate.create!(
  name: "email_generator",
  content: "Write a {{tone}} email about {{subject}} for {{audience}}",
  tags: ["email", "marketing"],
  output_format: "markdown"
)
```

### Running LLM Jobs

```ruby
# Synchronous
output = LLMJob.perform_now(
  template: template,
  model: "gpt-4",
  context: { tone: "professional", subject: "product launch", audience: "customers" }
)

# Asynchronous (recommended)
LLMJob.perform_later(
  template: template,
  model: "gpt-4",
  context: { tone: "professional", subject: "product launch", audience: "customers" }
)
```

### Multi-Context Provider (MCP)

Enrich prompts with dynamic data:

```ruby
context = MCPContext.new
context.fetch(:user_data, user_id: 123)
context.fetch(:recent_orders, limit: 5)
context.fetch(:github_issues, repo: "myorg/myrepo")

LLMJob.perform_later(template: template, context: context.to_h)
```

## Testing

Run the AI module test suite:

```bash
bin/synth test ai
```

The tests include:
- Unit tests for models and services
- Integration tests for job processing
- System tests for user workflows
- Mock providers to avoid API calls during testing

## Customization

### Adding New LLM Providers

1. Create a provider class in `app/services/llm_providers/`
2. Implement the standard interface (`call`, `models`, `pricing`)
3. Register the provider in the AI initializer

### Custom MCP Fetchers

```ruby
# app/services/mcp_fetchers/custom_fetcher.rb
class MCPFetchers::CustomFetcher < MCPFetchers::Base
  def fetch(params = {})
    # Your custom logic here
    { custom_data: "value" }
  end
end

# Register in config/initializers/ai.rb
Rails.application.config.ai.mcp_fetchers[:custom] = MCPFetchers::CustomFetcher
```

## API Endpoints

The AI module provides RESTful API endpoints:

- `GET /api/v1/prompt_templates` - List templates
- `POST /api/v1/prompt_templates` - Create template
- `POST /api/v1/llm_jobs` - Create LLM job
- `GET /api/v1/llm_outputs/:id` - Get output
- `POST /api/v1/llm_outputs/:id/feedback` - Submit feedback

## Troubleshooting

**API Key Issues:**
```bash
bin/synth doctor  # Validates API keys and connectivity
```

**Job Processing Issues:**
```bash
# Check Sidekiq queue
bin/rails console
Sidekiq::Queue.new.size

# Check failed jobs
Sidekiq::DeadSet.new.size
```

**MCP Fetcher Errors:**
Check logs in `log/mcp.log` for detailed error information.

## Development

When contributing to this module:

1. Follow the established patterns in existing code
2. Add tests for new features
3. Update this README for new functionality
4. Maintain backward compatibility when possible

## Removal

To remove this module:

```bash
bin/synth remove ai
```

**Warning**: This will remove all AI-related data. Backup your database first.

## Support

- Check the main [README.md](../../../README.md) for general troubleshooting
- Review the [CHANGELOG.md](../../../CHANGELOG.md) for recent changes
- Open issues on GitHub for bugs or feature requests
