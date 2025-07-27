# AI Module

This module provides comprehensive AI/LLM integration for Rails applications.

## Features

- Multi-provider AI support (OpenAI, Anthropic, Google)
- LLM job system with background processing
- Token usage tracking and cost estimation
- MCP (Model Context Protocol) integration
- Prompt management and versioning
- AI-powered features and workflows

## Installation

This module is automatically installed when you run:

```bash
railsplan new myapp --ai
```

Or manually add it to an existing application:

```bash
railsplan add ai
```

## Configuration

Add your AI provider API keys to your `.env` file:

```bash
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
GOOGLE_AI_API_KEY=your_google_ai_api_key_here
```

## Usage

The AI module provides several key components:

- **AI Providers**: Configurable providers for different AI services
- **LLM Jobs**: Background job processing for AI operations
- **Token Tracking**: Usage monitoring and cost estimation
- **MCP Integration**: Model Context Protocol for enhanced AI interactions

## Version

1.0.0 