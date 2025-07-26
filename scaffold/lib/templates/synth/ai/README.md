# AI Module

This module adds first‑class AI integration to your Rails app with versioned prompt templates, variable interpolation, audit history, and a comprehensive management interface.

## Features

### PromptTemplate Model

The `PromptTemplate` model provides a comprehensive system for managing AI prompts with the following capabilities:

- **Versioned prompt templates** - Track changes over time using PaperTrail
- **Variable interpolation** - Use `{{variable_name}}` syntax for dynamic content
- **Multiple output formats** - Support for JSON, Markdown, HTML partial, and text
- **Tagging system** - Organize templates with tags for easy filtering
- **Slug-based referencing** - API-friendly identifiers for templates
- **Preview functionality** - Test templates with sample data before use
- **Diff viewer** - Compare versions to see what changed

### PromptExecution Model

The `PromptExecution` model provides comprehensive audit history:

- **Input context tracking** - Store the variables passed to templates
- **Rendered prompt storage** - Keep the final prompt sent to the LLM
- **Execution metadata** - Track status, duration, tokens used, and model
- **Error handling** - Capture and display execution errors
- **User association** - Link executions to users for accountability

## Installation

Run the following command from your application root to install the AI module via the Synth CLI:

```bash
bin/synth add ai
```

This command will:
- Add necessary gems (`ruby-openai`, `paper_trail`) to your Gemfile
- Create models for `PromptTemplate` and `PromptExecution`
- Generate migrations for database tables and versioning
- Add controllers and views for template management
- Create comprehensive test coverage
- Add example seed data with sample templates

After installation, run:

```bash
rails db:migrate
rails db:seed
```

## Usage

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
