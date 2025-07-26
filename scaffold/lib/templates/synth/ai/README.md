# AI Module

This module adds first‑class AI integration to your Rails app. It installs prompt templates, an LLM job runner, and context providers for multi‑context prompts.

## Features

- **Prompt templates** store prompts with variables, tags, and versions
- **LLM jobs** run prompts asynchronously via Sidekiq, handling retries and logging inputs/outputs
- **Context providers** fetch data from your database, external APIs, files, semantic memory, or code

## Installation

Run the following command from your application root to install the AI module via the Synth CLI:

```sh
bin/synth add ai
```

This command will:
- Add necessary gems (ruby-openai, anthropic)
- Generate PromptTemplate and LlmOutput models
- Create an LlmJob for async processing
- Set up AI configuration
- Create AI service classes
- Add seed data for example prompt templates

## Configuration

After installation, configure your API keys in `.env`:

```
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
```

## Usage

### Creating Prompt Templates

```ruby
template = PromptTemplate.create!(
  name: 'my_prompt',
  description: 'Describe what this prompt does',
  content: 'Hello {{name}}, please help me with {{task}}',
  version: 1,
  tags: 'greeting,help'
)
```

### Executing Prompts

```ruby
result = Ai::PromptService.execute(
  template: template,
  context: { name: 'John', task: 'writing code' }
)
```

### Async Processing

```ruby
LlmJob.perform_later(template_id: template.id, context: { name: 'John' })
```

## Testing

Run AI-specific tests with:

```sh
bin/synth test ai
```

## Next Steps

After installation:
1. Configure your API keys
2. Run `rails db:seed` to load example templates
3. Try creating your own prompt templates
4. Extend the PromptService for your specific needs

Contributions and improvements are welcome!
