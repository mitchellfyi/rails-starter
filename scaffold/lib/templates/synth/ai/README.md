# AI Module

This module adds comprehensive AI integration to your Rails app with prompt templates, asynchronous LLM job processing, and multi-context providers for dynamic prompts.

## Features

- **Prompt Templates**: Versioned templates with variable interpolation, tags, and multiple output formats
- **Asynchronous LLM Jobs**: Background processing with Sidekiq for scalable AI operations
- **Multi-Provider Support**: OpenAI GPT and Anthropic Claude integration
- **Context Management**: Dynamic context injection for personalized prompts
- **Usage Tracking**: Token usage, processing time, and performance monitoring

## Installation

Run the following command from your application root to install the AI module:

```bash
bin/synth add ai
```

This command will:
- Add required gems (ruby-openai, anthropic, tiktoken_ruby)
- Generate models for PromptTemplate, LlmOutput, and LlmJob
- Create controllers for managing prompts and jobs
- Set up background job processors
- Create AI configuration initializer

## Post-Installation Setup

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Configure API keys in Rails credentials:**
   ```bash
   rails credentials:edit
   ```
   Add your API keys:
   ```yaml
   openai:
     api_key: your_openai_api_key
   anthropic:
     api_key: your_anthropic_api_key
   ```

3. **Add routes** to your `config/routes.rb`:
   ```ruby
   resources :prompt_templates
   resources :llm_jobs, only: [:index, :show, :create] do
     member do
       post :retry
     end
   end
   ```

4. **Create sample data:**
   ```bash
   bin/synth add ai_seeds
   ```

## Usage

### Creating Prompt Templates

```ruby
template = PromptTemplate.create!(
  name: "Product Description",
  content: "Write a compelling product description for {{product_name}} with the following features: {{features}}",
  description: "Generates marketing copy for products",
  tags: "marketing,copywriting",
  output_format: "html",
  active: true
)
```

### Processing LLM Jobs

```ruby
# Synchronous processing
processor = LlmProcessor.new(template, {
  product_name: "Smart Widget",
  features: "AI-powered, wireless, waterproof"
})
result = processor.execute

# Asynchronous processing
job = LlmJob.create!(
  prompt_template: template,
  context_data: { product_name: "Smart Widget", features: "..." },
  status: 'pending'
)
LlmProcessingJob.perform_later(job.id, template.id, job.context_data)
```

## Testing

Run AI-specific tests:

```bash
bin/synth test ai
```

## Configuration

The AI module can be configured in `config/initializers/ai.rb`:

```ruby
Rails.application.config.ai.default_model = 'gpt-4o'
Rails.application.config.ai.temperature = 0.7
Rails.application.config.ai.max_tokens = 2000
Rails.application.config.ai.timeout = 60
```

## Version

Current version: 1.0.0
