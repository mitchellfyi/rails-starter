# AI Multitenant Module - Complete Multi-Workspace AI System

This module provides a comprehensive multi-tenant AI system with workspace-scoped AI configurations, an AI playground interface, provider routing, credential security, and usage analytics.

## Features

### 🏢 Complete Multi-Tenant AI Architecture

- **Workspace-scoped AI credentials** - Each workspace manages its own AI providers and keys
- **Provider routing** - Automatic provider selection with fallback handling  
- **Security isolation** - Encrypted credential storage with workspace boundaries
- **Usage tracking** - Comprehensive analytics per workspace and provider

### 🎮 AI Playground Interface

- **Interactive playground** - Similar to OpenAI's playground interface
- **Real-time testing** - Test prompts and models directly in the UI
- **Template management** - Save and organize prompt templates per workspace
- **Model comparison** - Compare outputs across different models and providers

### 📊 Usage Analytics & Monitoring

- **Daily usage summaries** - Automated background job for usage aggregation
- **Cost tracking** - Monitor token usage and estimated costs per workspace
- **Performance metrics** - Track response times and success rates
- **Usage reports** - Detailed analytics dashboards for workspace admins

### 🔧 Enhanced LLMJob System

- **LLMJob.run(template:, workspace:, context:)** - Simple workspace-scoped execution
- **Automatic provider selection** - Intelligent routing based on model and availability
- **Comprehensive error handling** - Robust retry logic with fallback providers
- **Full audit trail** - Complete logging of all AI interactions

## Installation

Run the following command from your application root:

```bash
bin/railsplan add ai-multitenant
```

This installs:
- Complete AI provider and credential management system
- AI playground interface with real-time testing
- Usage tracking and analytics dashboard
- Daily summarization background job
- Comprehensive test suite for security and functionality
- Default OpenAI provider configuration

## Usage

### Basic Workspace-Scoped Execution

```ruby
# Simple execution with automatic provider selection
LLMJob.run(
  template: "Write a summary about {{topic}}",
  workspace: current_workspace,
  context: { topic: "Ruby on Rails" }
)

# With specific provider and model
LLMJob.run(
  template: "Generate JSON for {{entity}}",
  workspace: current_workspace,
  context: { entity: "user profile" },
  provider: "openai",
  model: "gpt-4"
)
```

### AI Playground Access

Visit `/ai/playground` in your workspace to access the interactive AI playground interface.

### Usage Analytics

Access usage analytics at `/ai/analytics` for workspace-level insights and cost tracking.

## Security & Multi-Tenancy

- **Encrypted credentials** - All API keys stored with Rails encryption
- **Workspace isolation** - Complete separation of AI resources per workspace
- **Access controls** - Role-based permissions for AI features
- **Audit logging** - Complete trail of all AI operations
- **Rate limiting** - Configurable limits per workspace

## Provider Support

Out of the box support for:
- OpenAI (GPT-3.5, GPT-4 series)
- Anthropic (Claude series)
- Cohere (Command series)
- Custom/Enterprise providers

## Background Jobs

### Daily Usage Summarization

Automatic daily job that:
- Aggregates token usage per workspace
- Calculates estimated costs
- Generates usage reports
- Sends optional usage notifications

Configure in `config/schedule.rb`:
```ruby
every 1.day, at: '2:00 am' do
  runner "AiUsageSummaryJob.perform_later"
end
```

## Configuration

The module is pre-configured with sensible defaults and includes:
- Default OpenAI provider setup
- Recommended model configurations
- Security best practices
- Performance optimizations

## Testing

Comprehensive test coverage includes:
- Provider routing and fallback logic
- Credential security and encryption
- Workspace isolation verification
- Usage tracking accuracy
- Playground functionality
- Background job processing

Run tests with:
```bash
bin/railsplan test ai-multitenant
```