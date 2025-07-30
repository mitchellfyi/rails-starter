# AI Usage Guide

This application is built with RailsPlan's AI-native architecture, providing powerful AI-assisted development capabilities.

## AI-Powered Features

### Code Generation
Use natural language to generate Rails code:

```bash
railsplan generate "Add a Blog model with title, content, and user association"
railsplan generate "Create a comment system for blog posts"
railsplan generate "Add user authentication with devise"
```

### Documentation Generation
Keep documentation up-to-date automatically:

```bash
railsplan generate docs              # Generate all documentation
railsplan generate docs schema       # Update only schema docs
railsplan generate docs --overwrite  # Force regeneration
```

## AI Configuration

### Provider Setup
Configure AI providers in `~/.railsplan/ai.yml`:

```yaml
default:
  provider: openai
  model: gpt-4o
  api_key: <%= ENV['OPENAI_API_KEY'] %>
  
profiles:
  development:
    provider: openai
    model: gpt-3.5-turbo
    api_key: <%= ENV['OPENAI_API_KEY'] %>
    
  production:
    provider: anthropic
    model: claude-3-sonnet
    api_key: <%= ENV['CLAUDE_KEY'] %>
```

### Environment Variables
Set these environment variables:

```bash
export OPENAI_API_KEY=your_openai_key
export CLAUDE_KEY=your_claude_key
export RAILSPLAN_AI_PROVIDER=openai
```

### API Key Rotation
To rotate API keys:

1. Update environment variables
2. Update `~/.railsplan/ai.yml`
3. Test with: `railsplan doctor`

## Prompt Management

### Prompt Logging
All AI interactions are logged in `.railsplan/prompts.log`:

```
[2024-01-01T12:00:00Z] PROMPT: Add a Blog model with title and content
[2024-01-01T12:00:05Z] RESPONSE: Generated blog.rb model with validations
[2024-01-01T12:00:05Z] FILES: app/models/blog.rb, db/migrate/001_create_blogs.rb
```

### Prompt Review
Review generated code before applying:

```bash
railsplan generate "your instruction" --dry-run
```

### Prompt Templates
Use consistent prompts for better results:

- **Models**: "Add a [ModelName] model with [attributes] and [associations]"
- **Controllers**: "Create a [controller] controller with [actions]"
- **Features**: "Implement [feature] with [specific requirements]"

## Context Management

### Application Context
RailsPlan maintains context in `.railsplan/context.json`:

```json
{
  "models": { /* model definitions */ },
  "routes": { /* API routes */ },
  "controllers": { /* controller info */ },
  "schema_hash": "abc123...",
  "last_updated": "2024-01-01T12:00:00Z"
}
```

### Updating Context
Keep context fresh for better AI results:

```bash
railsplan index  # Extract current application context
```

Context is automatically updated after successful code generation.

## Best Practices

### Writing Effective Prompts
- Be specific about requirements
- Mention existing models and associations
- Specify testing requirements
- Include validation and error handling needs

### Code Review Process
1. Generate code with AI
2. Review the generated files
3. Test the functionality
4. Refactor if needed
5. Commit with descriptive messages

### Security Considerations
- Review all generated code for security issues
- Validate input handling and sanitization
- Check authorization and authentication logic
- Audit database queries for injection risks

## Monitoring and Audit

### AI Usage Tracking
Monitor AI usage through:
- Prompt logs in `.railsplan/prompts.log`
- Generated file tracking
- Success/failure rates

### Code Quality
Ensure AI-generated code meets standards:
- Run tests after generation
- Use RuboCop for style checking
- Perform security audits
- Review for performance issues

## Troubleshooting

### Common Issues
- **API key invalid**: Check environment variables and configuration
- **Context stale**: Run `railsplan index` to refresh
- **Generation fails**: Review prompt clarity and application state

### Getting Help
- Check `.railsplan/prompts.log` for error details
- Use `railsplan doctor` for diagnostic information
- Review existing successful prompts for patterns
