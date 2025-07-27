# AI Agents Documentation

This document provides comprehensive information about AI agents available in this application.

## Overview

AI agents are automated assistants that can be deployed per workspace and bound to webhooks, buttons, or UI components. Each agent has its own configuration, system prompt, and capabilities.

## AgentRunner API

The main entry point for interacting with AI agents is the `AgentRunner` service.

### Basic Usage

```ruby
# Simple execution
response = AgentRunner.run(agent_id, user_input)

# With context
response = AgentRunner.run(agent_id, user_input, context: { user_name: "John" })

# With streaming
AgentRunner.run(agent_id, user_input, streaming: true) do |content, type|
  case type
  when :chunk
    puts "Chunk: #{content}"
  when :complete
    puts "Final: #{content}"
  end
end
```

### HTTP API Endpoints

#### Execute Agent (Synchronous)
```
POST /api/v1/agents/:agent_id/run
Content-Type: application/json
X-Webhook-Token: your-webhook-token

{
  "user_input": "Hello, how can you help me?",
  "context": {
    "user_name": "John",
    "workspace": "acme-corp"
  }
}
```

#### Execute Agent (Streaming)
```
POST /api/v1/agents/:agent_id/webhook?streaming=true
Content-Type: application/json
X-Webhook-Token: your-webhook-token

{
  "user_input": "Tell me a story",
  "context": {}
}
```

#### Execute Agent (Asynchronous)
```
POST /api/v1/agents/:agent_id/async
Content-Type: application/json

{
  "user_input": "Process this large document",
  "context": {}
}
```

#### Get Agent Configuration
```
GET /api/v1/agents/:agent_id/config
```

### Agent Configuration

Each agent has the following configuration options:

- **model_name**: The AI model to use (gpt-4, claude-3-sonnet, etc.)
- **temperature**: Controls randomness (0.0 to 2.0)
- **max_tokens**: Maximum response length
- **system_prompt**: The agent's instructions and personality
- **streaming_enabled**: Whether to support streaming responses
- **webhook_enabled**: Whether to send responses to configured webhooks

### Integration Examples

#### Chat UI Integration
```javascript
// Frontend streaming integration
const response = await fetch('/api/v1/agents/customer-support/webhook?streaming=true', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Webhook-Token': 'your-token'
  },
  body: JSON.stringify({
    user_input: message,
    context: { user_id: currentUser.id }
  })
});

const reader = response.body.getReader();
let result = '';

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  
  const chunk = new TextDecoder().decode(value);
  const lines = chunk.split('\n');
  
  for (const line of lines) {
    if (line.startsWith('data: ')) {
      const data = JSON.parse(line.slice(6));
      if (data.type === 'chunk') {
        result += data.content;
        updateChatUI(result);
      }
    }
  }
}
```

#### Dashboard Integration
```ruby
# In your dashboard controller
class DashboardController < ApplicationController
  def ai_assistant
    user_query = params[:query]
    context = {
      user_id: current_user.id,
      workspace: current_workspace.name,
      user_role: current_user.role
    }
    
    @response = AgentRunner.run('dashboard-assistant', user_query, 
      user: current_user, 
      context: context
    )
  end
end
```

#### Webhook Integration
```ruby
# Example webhook handler for external systems
class ExternalWebhookController < ApplicationController
  def handle_slack_command
    agent_response = AgentRunner.run('slack-bot', params[:text], 
      context: { 
        slack_user: params[:user_name],
        channel: params[:channel_name]
      }
    )
    
    render json: {
      text: agent_response,
      response_type: 'in_channel'
    }
  end
end
```

### Error Handling

The AgentRunner handles various error conditions:

- **Agent not found**: Returns `ArgumentError` with descriptive message
- **Agent not ready**: Returns `ArgumentError` if agent is inactive or misconfigured
- **API failures**: Logs errors and raises with context
- **Invalid context**: Validates required variables for prompts

### Security Considerations

- All webhook endpoints require authentication via `X-Webhook-Token` header
- Agents inherit workspace-level AI configuration and permissions
- User context is automatically included for authenticated requests
- Rate limiting should be configured at the application level

### Monitoring and Logging

All agent executions are logged with:
- Agent ID and name
- User ID (if authenticated)
- Context keys (not values for privacy)
- Execution time and status
- Error details if applicable

Execution records are stored in:
- `PromptExecution` model for audit trail
- `LLMOutput` model for response storage

## Available Agent Models

- **gpt-3.5-turbo**: Fast and cost-effective for most tasks
- **gpt-4**: High-quality responses with advanced reasoning
- **gpt-4-turbo**: Latest GPT-4 with improved speed and context
- **gpt-4o**: Optimized GPT-4 for better performance
- **claude-3-haiku**: Fast Anthropic model for simple tasks
- **claude-3-sonnet**: Balanced Anthropic model for most use cases
- **claude-3-opus**: Anthropic's most capable model for complex tasks

## Best Practices

1. **System Prompts**: Write clear, specific instructions for your agents
2. **Context**: Provide relevant context but avoid sensitive information
3. **Error Handling**: Always handle potential failures gracefully
4. **Streaming**: Use streaming for long responses to improve UX
5. **Webhooks**: Use async execution for time-consuming tasks
6. **Testing**: Test agents thoroughly with various inputs
7. **Monitoring**: Monitor token usage and response times

## Support

For questions about AI agents, please refer to:
- [AI Module Documentation](modules/ai.md)
- [API Documentation](api.json)
- [Rails SaaS Starter Template Documentation](README.md)
