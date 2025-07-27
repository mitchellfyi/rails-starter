# AI Module - Enhanced LLM Job System with Per-Workspace AI Configuration

This module adds first‑class AI integration to your Rails app with **per-workspace AI configuration**, **versioned prompt templates**, variable interpolation, comprehensive audit history, preview functionality, and a management interface with safety features.

## Features

### 🏢 Per-Workspace AI Configuration

Each workspace can manage their own AI providers, API keys, and model settings:

#### AiProvider Model
- **Multi-provider support** - OpenAI, Anthropic, Cohere with extensible architecture
- **Provider-specific configuration** - Custom API endpoints, supported models, default settings
- **Connectivity testing** - Built-in "ping" functionality to validate provider access
- **Priority ordering** - Organize providers by preference in admin interfaces

#### AiCredential Model (Per Workspace)
- **Encrypted API keys** - Secure storage using Rails' built-in encryption
- **Model preferences** - Configure preferred models per credential
- **Temperature/token controls** - Fine-tune model behavior per workspace
- **Provider-specific settings** - Custom configuration per AI provider
- **System prompts** - Default prompts for consistent behavior
- **Usage tracking** - Monitor credential usage and last access times
- **Connection validation** - Test credentials with comprehensive health checks

#### Workspace-Scoped Execution
- **LLMJob.for(workspace).run(...)** - Automatic credential selection and scoping
- **Provider selection** - Choose specific AI providers per job
- **Fallback handling** - Automatic failover to backup credentials
- **Usage monitoring** - Track AI usage per workspace

### 🔧 AI Provider Management

#### Admin Interface
- **Provider configuration** - Manage available AI providers system-wide
- **Model support** - Configure which models each provider supports
- **API endpoint management** - Custom endpoints for enterprise/self-hosted providers
- **Default settings** - System-wide defaults for temperature, max tokens, etc.

#### Workspace Admin Interface
- **Credential management** - Per-workspace AI credential configuration
- **Connection testing** - Validate API keys and model access
- **Usage analytics** - Monitor AI usage and costs per workspace
- **Default preferences** - Set workspace-specific AI defaults

### 🧪 Validation & Testing ("Ping" Functionality)

#### Comprehensive Testing
- **Basic connectivity** - Verify API endpoints and authentication
- **Model validation** - Test access to specific models
- **End-to-end testing** - Full prompt execution with simple test cases
- **Error diagnosis** - Detailed error reporting for troubleshooting

#### AiProviderTestService
- **Multi-level testing** - Progressive validation from basic to complex
- **Result storage** - Test history and status tracking
- **Performance metrics** - Response time and reliability monitoring
- **Automated testing** - Scheduled health checks for critical credentials

### 🎯 Enhanced PromptTemplate System

The `PromptTemplate` model provides a comprehensive system for managing AI prompts with advanced versioning capabilities:

#### Core Features
- **Versioned prompt templates** - Full version tracking using PaperTrail with semantic versioning
- **Variable interpolation** - Use `{{variable_name}}` syntax for dynamic content  
- **Multiple output formats** - Support for JSON, Markdown, HTML, and text
- **Tagging system** - Organize templates with tags for easy filtering
- **Slug-based referencing** - API-friendly identifiers for templates
- **Preview functionality** - Test templates with sample data before publishing
- **Publishing workflow** - Draft → Preview → Publish lifecycle for safety

#### Versioning & Safety Features  
- **Version history tracking** - Complete audit trail of all changes
- **Side-by-side diff viewer** - Compare versions to see exactly what changed
- **Publishing controls** - Prevent accidental deployment of untested templates
- **Rollback capability** - Revert to previous versions when needed
- **Version branching** - Create new versions from any existing version
- **Latest version detection** - Automatically identify current active versions

#### Preview & Testing
- **Live preview system** - Test templates with custom context data before execution
- **Variable validation** - Real-time feedback on missing or invalid variables  
- **Sample context generation** - Automatic test data for quick previews
- **Execution simulation** - Preview rendered output without calling LLM APIs
- **Error handling preview** - See validation errors before deployment

### 📋 PromptExecution Model

Enhanced execution tracking with comprehensive audit capabilities:
- **Input context tracking** - Store the variables passed to templates
- **Rendered prompt storage** - Keep the final prompt sent to the LLM  
- **Execution metadata** - Track status, duration, tokens used, and model
- **Error handling** - Capture and display execution errors with context
- **User association** - Link executions to users for accountability
- **Preview executions** - Track template testing separately from live runs
- **Workspace association** - Link executions to specific workspaces
- **Credential tracking** - Record which AI credential was used

### 🔄 Asynchronous Job Processing
- **LLMJob**: Sidekiq-powered background job for AI prompt execution
- **Retry Logic**: Exponential backoff with jitter (5 retries max, up to 5 minutes delay)
- **Queue Management**: Configurable queue priorities (high, default, low)
- **Workspace Integration**: Automatic credential selection based on workspace

### 📊 Output Storage & Management
- **LLMOutput Model**: Stores job results with full context
- **Multiple Formats**: Support for text, JSON, Markdown, and HTML outputs
- **Status Tracking**: pending → processing → completed/failed
- **Associations**: Links to users, agents, workspaces, and credentials

### 👍 User Feedback System
- **Thumbs Up/Down**: Simple feedback mechanism
- **Re-run**: Execute identical job with same parameters
- **Regenerate**: Create new job with modified context/model
- **Feedback Analytics**: Structured logging for quality metrics

### 🔍 Observability
- **Structured Logging**: JSON logs for job execution, errors, and feedback
- **Error Handling**: Graceful failure handling with detailed error messages
- **Job Tracking**: Unique job IDs for tracing and debugging
- **Workspace Analytics**: Per-workspace usage and performance metrics

## Installation

Run the following command from your application root:

```bash
bin/synth add ai
```

This command will:
- Add necessary gems (`ruby-openai`, `paper_trail`) to your Gemfile
- Create models for `PromptTemplate`, `PromptExecution`, `AiProvider`, and `AiCredential`
- Generate migrations for database tables and versioning
- Add controllers and views for template and credential management
- Create comprehensive test coverage
- Add example seed data with sample templates and AI providers

After installation, run:

```bash
rails db:migrate
rails db:seed
```

## Usage

### Setting Up AI Providers and Credentials

```ruby
# Create AI providers (usually done via seeds or admin interface)
openai = AiProvider.create!(
  name: 'OpenAI',
  slug: 'openai',
  api_base_url: 'https://api.openai.com',
  supported_models: ['gpt-4', 'gpt-3.5-turbo'],
  default_config: { temperature: 0.7, max_tokens: 4096 }
)

# Workspace admin creates credentials
credential = workspace.ai_credentials.create!(
  ai_provider: openai,
  name: 'Production OpenAI',
  api_key: ENV['OPENAI_API_KEY'],
  preferred_model: 'gpt-4',
  temperature: 0.8,
  max_tokens: 2048,
  is_default: true
)
```

### Workspace-Scoped LLM Execution

```ruby
# Simple workspace-scoped execution
LLMJob.for(workspace).run(
  template: "Write a summary about {{topic}}",
  context: { topic: "Ruby on Rails" },
  provider: "openai",
  user: current_user
)

# With specific model and format
LLMJob.for(workspace).run(
  template: "Generate JSON data for {{entity}}",
  context: { entity: "user profile" },
  provider: "openai",
  model: "gpt-3.5-turbo",
  format: "json",
  user: current_user
)

# Check available providers for workspace
runner = LLMJob.for(workspace)
puts runner.available_providers # => ["openai", "anthropic"]
puts runner.configured? # => true
```

### Direct Credential Usage

```ruby
# Get default credential for a provider
credential = AiCredential.default_for(workspace, "openai")

# Or get the best available credential
credential = AiCredential.best_for(workspace, "openai")

# Execute via credential
credential.create_job_runner.run(
  template: "Hello {{name}}",
  context: { name: "World" },
  user: current_user
)

# Synchronous execution (for testing)
result = credential.create_job_runner.run_sync(
  template: "Test prompt",
  context: {},
  user: current_user
)
```

### Connection Testing and Validation

```ruby
# Test a specific credential
result = credential.test_connection
if result[:success]
  puts "✅ Connection successful: #{result[:message]}"
else
  puts "❌ Connection failed: #{result[:error]}"
end

# Test all credentials for a workspace
runner = LLMJob.for(workspace)
test_results = runner.test_all_credentials
test_results.each do |provider, results|
  puts "#{provider.capitalize}:"
  results.each do |test|
    status = test[:test_result][:success] ? "✅" : "❌"
    puts "  #{status} #{test[:credential_name]}"
  end
end

# Check if credential passed last test
if credential.test_successful?
  puts "Last test passed at #{credential.last_tested_at}"
else
  puts "Last test failed or never tested"
end
```

### Advanced Configuration

```ruby
# Create credential with provider-specific settings
anthropic_credential = workspace.ai_credentials.create!(
  ai_provider: anthropic_provider,
  name: 'Claude Production',
  api_key: ENV['ANTHROPIC_API_KEY'],
  preferred_model: 'claude-3-opus-20240229',
  temperature: 0.3,
  max_tokens: 1000,
  system_prompt: 'You are a helpful assistant specialized in technical documentation.',
  provider_config: {
    top_p: 0.9,
    top_k: 40
  }
)

# Use custom configuration in job
LLMJob.perform_later(
  template: "Explain {{concept}}",
  model: anthropic_credential.preferred_model,
  context: { concept: "dependency injection" },
  format: "markdown",
  user_id: user.id,
  ai_credential_id: anthropic_credential.id,
  workspace_id: workspace.id
)
```

### Legacy Usage (Backward Compatibility)

```ruby
# Original LLMJob usage still works
LLMJob.perform_later(
  template: "Hello {{name}}",
  model: "gpt-4",
  context: { name: "World" },
  format: "text",
  user_id: current_user.id
)
```

### Creating Prompt Templates

```ruby
# Create a template programmatically
template = PromptTemplate.create!(
  name: 'Welcome Email',
  description: 'Generate personalized welcome emails',
  prompt_body: 'Hello {{user_name}}, welcome to {{company}}!',
  output_format: 'markdown',
  tags: ['email', 'onboarding'],
  active: true
)
```

### Using Variable Interpolation

Templates support `{{variable_name}}` syntax for dynamic content:

```ruby
# Template with variables
template = PromptTemplate.create!(
  name: 'Product Description',
  prompt_body: 'Create a description for {{product_name}} in {{category}} category. Features: {{features}}'
)

# Check required variables
template.variable_names
# => ["product_name", "category", "features"]

# Render with context
context = {
  product_name: "Smart Watch",
  category: "Electronics", 
  features: "Heart rate monitoring, GPS, waterproof"
}

rendered = template.render_with_context(context)
# => "Create a description for Smart Watch in Electronics category. Features: Heart rate monitoring, GPS, waterproof"
```

### Validation and Preview

```ruby
# Validate context has all required variables
missing = template.validate_context({ product_name: "Watch" })
# => ["category", "features"] (missing variables)

valid = template.validate_context(context)
# => true (all variables present)

# Generate preview with sample data
preview = template.preview_with_sample_context
# => "Create a description for [product_name_value] in [category_value] category..."
```

### Execution Tracking

```ruby
# Create an execution record
execution = PromptExecution.create!(
  prompt_template: template,
  user: current_user,
  input_context: context,
  rendered_prompt: template.render_with_context(context),
  status: 'pending'
)

# Update when processing starts
execution.update!(
  status: 'processing',
  started_at: Time.current,
  model_used: 'gpt-4'
)

# Update when completed
execution.update!(
  status: 'completed',
  completed_at: Time.current,
  output: "Generated product description...",
  tokens_used: 150
)

# Check execution results
execution.success?     # => true
execution.duration     # => 2.3 (seconds)
```

### Version History and Diffs

```ruby
# Templates are automatically versioned on changes
template.update!(name: 'Updated Name')

# Access version history
template.versions.count  # => 1
version = template.versions.first

# Get previous version
previous = version.reify
previous.name  # => "Original Name"

# View changes
version.changeset
# => {"name"=>["Original Name", "Updated Name"]}
```

## Web Interface

The module provides a complete web interface for managing prompt templates:

### Template Management
- **Index page** (`/prompt_templates`) - Browse and filter templates
- **Show page** (`/prompt_templates/:id`) - View template details and history
- **Create/Edit forms** - Rich interface for template authoring
- **Tag management** - Dynamic tag addition and removal

### Preview and Testing
- **Live preview** - Test templates with custom context data
- **Variable validation** - Real-time feedback on missing variables
- **Sample context** - Automatic generation of test data

### Version Control
- **Version history** - Browse all changes to a template
- **Diff viewer** - Side-by-side comparison of versions
- **Restore functionality** - Roll back to previous versions

### Execution Audit
- **Execution history** - View all uses of a template
- **Performance metrics** - Track duration and token usage
- **Error tracking** - Monitor and debug failed executions

## API Usage

Templates can be referenced by slug for API access:

```ruby
# Find template by slug
template = PromptTemplate.find_by!(slug: 'welcome_email')

# Execute via API
POST /prompt_templates/:id/executions
{
  "context": {
    "user_name": "John Doe",
    "company": "Acme Corp"
  }
}
```

## Configuration

The module adds configuration options in `config/initializers/ai.rb`:

```ruby
Rails.application.config.ai.default_model = 'gpt-4'
Rails.application.config.ai.default_temperature = 0.7
Rails.application.config.ai.max_tokens = 4096
Rails.application.config.ai.output_formats = %w[json markdown html_partial text]
```

## Scopes and Filtering

```ruby
# Filter by tag
PromptTemplate.by_tag('email')

# Filter by output format  
PromptTemplate.by_output_format('json')

# Active templates only
PromptTemplate.where(active: true)

# Recent executions
PromptExecution.recent.limit(10)

# Successful executions
PromptExecution.successful

# Failed executions  
PromptExecution.failed
```

## Testing

The module includes comprehensive test coverage:

```bash
# Run AI module tests
rails test test/models/prompt_template_test.rb
rails test test/models/prompt_execution_test.rb
rails test test/controllers/prompt_templates_controller_test.rb
rails test test/controllers/prompt_executions_controller_test.rb
```

## Customization

### Extending the Models

```ruby
# Add custom validation
class PromptTemplate < ApplicationRecord
  validate :custom_validation
  
  private
  
  def custom_validation
    # Your custom logic
This installs:
- LLMJob worker with Sidekiq configuration
- LLMOutput model and migration
- Controllers for web and API access
- Routes for feedback and job management
- Comprehensive test suite
- Example views with TailwindCSS

## Configuration

### Environment Variables

Add to your `.env` file:

```env
# LLM API Configuration
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
REDIS_URL=redis://localhost:6379/1
```

### Sidekiq Setup

Start Sidekiq to process jobs:

```bash
bundle exec sidekiq
```

Configure queues in `config/application.rb`:

```ruby
config.active_job.queue_adapter = :sidekiq
```

## Usage

### Basic Job Queuing

```ruby
# Simple text generation
LLMJob.perform_later(
  template: "Write a summary about {{topic}}",
  model: "gpt-4",
  context: { topic: "Ruby on Rails" },
  format: "text",
  user_id: current_user.id
)

# JSON output
LLMJob.perform_later(
  template: "Generate data for {{entity}} in JSON format",
  model: "gpt-3.5-turbo", 
  context: { entity: "user profile" },
  format: "json"
)

# Markdown documentation
LLMJob.perform_later(
  template: "Create documentation for {{feature}}",
  model: "claude-3-opus",
  context: { feature: "authentication system" },
  format: "markdown"
)
```

### API Usage

Queue jobs via HTTP API:

```bash
curl -X POST /api/v1/llm_jobs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "template": "Explain {{concept}} to a beginner",
    "model": "gpt-4",
    "context": { "concept": "machine learning" },
    "format": "text"
  }'
```

Response:
```json
{
  "job_id": "abc123",
  "output_id": 456,
  "status": "queued",
  "estimated_completion": "2024-01-15T10:35:00Z"
}
```

### Feedback & Re-execution

```ruby
output = LLMOutput.find(456)

# Provide feedback
output.set_feedback!('thumbs_up', user: current_user)

# Re-run with identical parameters
output.re_run!

# Regenerate with new context
output.regenerate!(
  new_context: { concept: "deep learning" },
  new_model: "gpt-4"
)
```

### Web Interface

Access outputs via web interface:
- `/llm_outputs` - List all outputs for current user
- `/llm_outputs/:id` - View specific output with feedback controls
- Feedback buttons for thumbs up/down
- Re-run and regenerate actions

## Models

### LLMOutput

```ruby
class LLMOutput < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :agent, optional: true
  
  validates :template_name, :model_name, :format, :status, presence: true
  validates :format, inclusion: { in: %w[text json markdown html] }
  validates :status, inclusion: { in: %w[pending processing completed failed] }
  
  enum feedback: { none: 0, thumbs_up: 1, thumbs_down: 2 }
  
  scope :completed, -> { where(status: 'completed') }
  scope :by_template, ->(template) { where(template_name: template) }
  scope :by_model, ->(model) { where(model_name: model) }
end
```

Key attributes:
- `template_name`: Original template string
- `model_name`: LLM model used (gpt-4, claude-3-opus, etc.)
- `context`: JSON hash of template variables
- `format`: Output format (text, json, markdown, html)
- `prompt`: Final interpolated prompt sent to LLM
- `raw_response`: Raw LLM API response
- `parsed_output`: Processed output for display
- `feedback`: User feedback (none, thumbs_up, thumbs_down)
- `status`: Job status (pending, processing, completed, failed)

## Testing

The module includes comprehensive tests:

```bash
# Run all LLM tests
bin/rails test test/jobs/llm_job_test.rb
bin/rails test test/models/llm_output_test.rb
bin/rails test test/controllers/llm_outputs_controller_test.rb
bin/rails test test/integration/llm_job_system_test.rb

# Run specific test module
bin/synth test ai
```

### Test Helpers

Use provided test helpers for mocking:

```ruby
# In your tests
include LLMTestHelper

# Create test output
output = create_test_llm_output(user: @user, format: 'json')

# Mock API success
stub_llm_api_success(format: 'text')

# Mock API failure  
stub_llm_api_failure

# Assert job enqueued
assert_llm_job_enqueued(template: "Hello {{name}}", model: "gpt-4") do
  MyService.queue_llm_job
end
```

## Error Handling

### Retry Configuration

```ruby
# Custom retry logic in LLMJob
sidekiq_retry_in do |count, exception|
  base_delay = 5 # seconds
  max_delay = 300 # 5 minutes max
  jitter = rand(0.5..1.5)
  
  delay = [base_delay * (2 ** count) * jitter, max_delay].min
  Rails.logger.info "LLMJob retry #{count + 1}/5 in #{delay.round(2)} seconds"
  delay
end
```

### Death Handlers

Failed jobs update LLMOutput status:

```ruby
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, ex) do
    if job['class'] == 'LLMJob'
      LLMOutput.find_by(job_id: job['jid'])&.update!(
        status: 'failed',
        raw_response: "Job failed permanently: #{ex.message}"
      )
    end
  end
end
```

### Adding Custom Output Formats

```ruby
# In config/initializers/ai.rb
Rails.application.config.ai.output_formats = %w[
  json 
  markdown 
  html_partial 
  text
  yaml
  xml
].freeze
```

### Custom Context Processors

```ruby
class PromptTemplate < ApplicationRecord
  def render_with_enhanced_context(context)
    enhanced_context = context.merge(
      timestamp: Time.current.iso8601,
      app_name: Rails.application.class.module_parent_name
    )
    render_with_context(enhanced_context)
## Monitoring

### Structured Logging

All job activities are logged with structured data:

```json
{
  "level": "info",
  "message": "LLMJob completed successfully",
  "job_id": "abc123",
  "output_id": 456,
  "template": "Welcome {{name}}",
  "model": "gpt-4",
  "user_id": 789,
  "response_length": 150,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Sidekiq UI

Monitor job queues via Sidekiq web UI:

```ruby
# In routes.rb
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq'
```

## Customization

### Adding New LLM Providers

Extend the `call_llm_api` method in `LLMJob`:

```ruby
def call_llm_api(model, prompt, format)
  case model
  when /^gpt-/
    openai_client.chat(prompt, format)
  when /^claude-/
    anthropic_client.complete(prompt, format)
  when /^llama-/
    ollama_client.generate(prompt, format)
  else
    raise "Unsupported model: #{model}"
  end
end
```

## Integration with LLM Job System

The prompt templates integrate seamlessly with background job processing:

```ruby
# Example LLM job
class LLMJob < ApplicationJob
  def perform(template_slug:, context:, user:)
    template = PromptTemplate.find_by!(slug: template_slug)
    
    execution = PromptExecution.create!(
      prompt_template: template,
      user: user,
      input_context: context,
      rendered_prompt: template.render_with_context(context),
      status: 'processing',
      started_at: Time.current
    )
    
    begin
      # Call LLM API
      response = call_llm_api(execution.rendered_prompt)
      
      execution.update!(
        status: 'completed',
        output: response.output,
        completed_at: Time.current,
        tokens_used: response.usage.total_tokens
      )
    rescue => error
      execution.update!(
        status: 'failed',
        error_message: error.message,
        completed_at: Time.current
      )
      raise
    end
  end
end
```

### Custom Context Fetchers

Create reusable context fetchers:

```ruby
class ContextFetcher
  def self.user_profile(user_id)
    user = User.find(user_id)
    {
      name: user.name,
      email: user.email,
      join_date: user.created_at.strftime("%B %Y"),
      plan: user.subscription&.plan_name
    }
  end
end

# Usage
LLMJob.perform_later(
  template: "Create welcome email for {{name}} on {{plan}} plan",
  model: "gpt-4",
  context: ContextFetcher.user_profile(user.id)
)
```

## Security Considerations

- **Input Validation**: All user inputs are validated and sanitized
- **Access Control**: Users can only access their own outputs
- **API Authentication**: API endpoints require authentication
- **Rate Limiting**: Consider implementing rate limits for job creation
- **Data Privacy**: Sensitive context data is stored securely

## Performance Tips

- **Batch Processing**: Use queue priorities for different urgency levels
- **Context Optimization**: Keep context data minimal to reduce payload size
- **Caching**: Cache frequently used templates and model configurations
- **Monitoring**: Track job execution times and failure rates

## Next Steps

After installation:

1. Configure your OpenAI or other LLM API keys in credentials
2. Run migrations and seed data: `rails db:migrate db:seed`
3. Visit `/prompt_templates` to explore the interface
4. Create your first custom prompt template
5. Test the preview and execution functionality

For advanced usage, consider integrating with the Multi-Context Provider (MCP) module for dynamic context fetching from external sources.

## Contributing

Contributions and improvements are welcome. Keep this README up to date as the module evolves.
1. **Configure API Keys**: Add LLM provider credentials to `.env`
2. **Start Sidekiq**: `bundle exec sidekiq` to process jobs
3. **Test the System**: Run the test suite to verify installation
4. **Create First Job**: Queue a test job to confirm functionality
5. **Monitor Performance**: Set up logging and monitoring
6. **Customize Views**: Adapt the provided views to match your design system

## Contributing

Improvements and features are welcome! When contributing:

1. **Follow Patterns**: Use existing conventions for consistency
2. **Add Tests**: Include comprehensive test coverage
3. **Update Documentation**: Keep this README current
4. **Consider Performance**: Optimize for production usage
5. **Security Review**: Ensure secure handling of user data
