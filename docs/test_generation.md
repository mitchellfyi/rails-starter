# AI Test Generation Feature

This document describes the new AI-powered test generation feature in RailsPlan.

## Overview

The `railsplan generate test` command allows developers to generate full-featured Rails tests using natural language descriptions. The AI automatically detects the appropriate test type and generates comprehensive test code following Rails conventions.

## Usage

### Basic Usage

```bash
railsplan generate test "User signs up with email and password"
```

This command will:
1. Analyze the instruction to determine the test type (system, request, model, etc.)
2. Generate appropriate test code using AI
3. Create test files in the correct location with proper naming
4. Include realistic test steps and assertions
5. Follow Rails testing conventions and best practices

### Command Options

- `--type=TYPE` - Override auto-detection (model|request|system|job|controller|integration|unit)
- `--dry-run` - Preview the generated test without writing files
- `--force` - Skip confirmation prompts and write files immediately
- `--validate` - Run syntax checks on generated test files
- `--profile=PROFILE` - Use specific AI provider profile
- `--creative` - Use more creative/exploratory AI responses
- `--max-tokens=N` - Limit AI response length

### Examples

```bash
# System test for user workflows
railsplan generate test "User signs up with email and password"

# API/Request test
railsplan generate test "API returns user data in JSON format" --type=request

# Model test
railsplan generate test "User model validates email uniqueness"

# Job test  
railsplan generate test "Email notification job sends welcome email"

# Controller test
railsplan generate test "Users controller handles create action"

# Preview without writing files
railsplan generate test "User authentication flow" --dry-run

# Force generation without confirmation
railsplan generate test "Payment processing" --force --validate
```

## Test Type Auto-Detection

The system automatically detects the appropriate test type based on natural language patterns:

### System Tests
- **Keywords**: signup, signin, visit, click, fill, submit, user interaction, browser
- **Examples**: 
  - "User signs up with email and password"
  - "Admin visits dashboard and clicks delete button"
  - "User completes checkout flow"

### Request/API Tests  
- **Keywords**: api, endpoint, request, response, POST, GET, PUT, DELETE, http, json, status
- **Examples**:
  - "API returns user data in JSON format"
  - "GET /users returns 200 status"
  - "POST /users creates new user"

### Model Tests
- **Keywords**: model, validation, association, scope, database, .save, .create, .find
- **Examples**:
  - "User model validates email uniqueness"
  - "User has many posts association"
  - "User.create saves record to database"

### Job Tests
- **Keywords**: job, perform, queue, background, sidekiq, delayed, async
- **Examples**:
  - "Email notification job sends welcome email"
  - "Background job processes payment"
  - "Queue job for data export"

### Controller Tests
- **Keywords**: controller, action, params, redirect, render, before_action
- **Examples**:
  - "Users controller handles create action"
  - "Controller redirects after successful save"
  - "Admin controller requires authentication"

## Framework Support

The generator supports both RSpec and Minitest frameworks:

### Auto-Detection
- **RSpec**: Detected when `spec/spec_helper.rb` or `spec/rails_helper.rb` exists
- **Minitest**: Rails default, used when no RSpec files found

### Generated Test Structure

#### RSpec
- System tests: `spec/system/`
- Request tests: `spec/requests/`
- Model tests: `spec/models/`
- Job tests: `spec/jobs/`
- Controller tests: `spec/controllers/`

#### Minitest
- System tests: `test/system/`
- Request tests: `test/integration/`
- Model tests: `test/models/`
- Job tests: `test/jobs/`
- Controller tests: `test/controllers/`

## AI Provider Configuration

Before using test generation, configure an AI provider:

### Create AI Configuration File

```bash
mkdir -p ~/.railsplan
cat > ~/.railsplan/ai.yml << EOF
default:
  provider: openai
  model: gpt-4o
  api_key: <%= ENV['OPENAI_API_KEY'] %>
profiles:
  test:
    provider: anthropic
    model: claude-3-sonnet
    api_key: <%= ENV['CLAUDE_KEY'] %>
EOF
```

### Environment Variables

```bash
export OPENAI_API_KEY=your_key_here
export RAILSPLAN_AI_PROVIDER=openai
```

## Application Context

The generator uses application context from `.railsplan/context.json` to create relevant tests:

### Extract Context
```bash
railsplan index  # Extract models, routes, controllers, schema
```

### Context Information Used
- **Models**: Associations, validations, scopes
- **Controllers**: Actions, routes
- **Database Schema**: Tables, columns, types
- **Routes**: Endpoints, HTTP verbs
- **Installed Modules**: Available features

## Integration with Doctor Command

The `railsplan doctor` command can automatically generate tests for missing coverage:

```bash
# Scan for missing tests
railsplan doctor

# Auto-generate tests for missing coverage
railsplan doctor --fix
```

The doctor command will:
1. Identify models and controllers without tests
2. Generate appropriate test files using AI
3. Report on test coverage improvements

## Generated Test Features

### System Tests
- Complete user workflows with Capybara
- Realistic form interactions (fill_in, click_button)
- Page content assertions (expect(page).to have_content)
- JavaScript interaction support (`js: true` when needed)

### Request Tests
- HTTP endpoint testing (GET, POST, PUT, DELETE)
- Response status and header validation
- JSON response parsing and assertions
- Authentication and authorization testing

### Model Tests
- Validation testing with edge cases
- Association behavior verification
- Scope and class method testing
- Database constraint validation

### Job Tests
- Job execution and side effect testing
- External service mocking
- Queue and scheduling verification
- Error handling and retry logic

### Controller Tests
- Action isolation and parameter handling
- Response rendering and redirect testing
- Authentication and authorization
- Instance variable assignment verification

## Logging and Recovery

All AI interactions are logged to `.railsplan/prompts.log`:

```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "prompt": "Generate system test for...",
  "response": "Generated test code...",
  "metadata": {
    "provider": "openai",
    "model": "gpt-4o",
    "instruction": "User signs up",
    "test_type": "system"
  }
}
```

## Best Practices

### Writing Good Test Instructions
- Be specific about the behavior to test
- Include relevant context (user roles, data states)
- Mention expected outcomes
- Use domain-specific language

### Examples of Good Instructions
✅ **Good**: "User with valid email signs up and receives welcome email"
✅ **Good**: "Admin can delete user account and sees confirmation message"
✅ **Good**: "API returns 404 when user not found"

❌ **Avoid**: "Test user stuff"
❌ **Avoid**: "Make tests work"

### Customizing Generated Tests
- Review generated tests before running
- Add additional edge cases as needed
- Customize test data and fixtures
- Adjust assertions for specific requirements

## Troubleshooting

### Common Issues

**AI Provider Not Configured**
```
❌ AI provider not configured
```
Solution: Configure AI provider in `~/.railsplan/ai.yml`

**Context Not Available**
```
❌ Context not found
```
Solution: Run `railsplan index` to extract application context

**Invalid Test Type**
```
❌ Unknown test type: invalid_type
```
Solution: Use valid test types: system, request, model, job, controller, integration, unit

### Validation Errors

Run with `--validate` to check generated test syntax:
```bash
railsplan generate test "User signup" --validate
```

### Getting Help

```bash
railsplan generate --help
railsplan doctor --help
```

## Advanced Usage

### Custom Test Types
Override auto-detection for specific needs:
```bash
railsplan generate test "User workflow" --type=integration
```

### Multiple Test Generation
Generate tests for multiple scenarios:
```bash
railsplan generate test "User signs up successfully"
railsplan generate test "User signup fails with invalid email"
railsplan generate test "User signup requires password confirmation"
```

### CI/CD Integration
Use in automated environments:
```bash
railsplan generate test "API regression test" --force --silent
```

This comprehensive test generation feature makes it easy to maintain good test coverage while following Rails conventions and best practices.