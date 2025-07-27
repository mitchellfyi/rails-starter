# Module-Specific Test Templates

This directory contains reusable shared examples for common patterns across modules in the Rails SaaS Starter Template.

## Available Shared Examples

### LLM Prompt Shared Examples (`llm_prompt.rb`)

These examples test common patterns for models that handle prompts, templates, and context variables.

#### Available Examples:

- **`'a prompt with variables'`** - Tests extraction of variables from `{{variable}}` syntax
- **`'a prompt with context rendering'`** - Tests rendering prompts with variable substitution
- **`'a prompt with validation'`** - Tests basic validation requirements (name, prompt_text, slug format)
- **`'a prompt with slug generation'`** - Tests automatic slug generation from name
- **`'a versioned prompt'`** - Tests version management functionality
- **`'a prompt with context validation'`** - Tests validation of context completeness

#### Usage Example:

```ruby
RSpec.describe MyPromptModel do
  subject { MyPromptModel.new(name: 'Test', prompt_text: 'Hello {{name}}!') }

  include_examples 'a prompt with variables'
  include_examples 'a prompt with context rendering'
  include_examples 'a prompt with validation'
  include_examples 'a prompt with slug generation'
  include_examples 'a versioned prompt'
  include_examples 'a prompt with context validation'
end
```

#### Required Methods:

Your model should implement:
- `variable_names` - Returns array of variable names from prompt
- `render_with_context(context)` - Renders prompt with variables replaced
- `validate_context(context)` - Returns true or array of missing variables
- `create_new_version!(attributes = {})` - Creates new version of prompt
- `latest_version?` - Returns true if this is the latest version

#### Required Attributes:

- `name` - Prompt name
- `prompt_text` - The actual prompt content
- `slug` - URL-friendly identifier
- `version` - Version string (e.g., "1.0.0")
- `status` - Prompt status (e.g., "draft", "active", "archived")

### Audit Logger Shared Examples (`audit_logger.rb`)

These examples test common patterns for audit logging functionality across modules.

#### Available Examples:

- **`'an audit logger'`** - Tests basic audit log creation via `.create_log` class method
- **`'an audit log with scopes'`** - Tests common query scopes (recent, for_action, for_resource_type, for_user)
- **`'an audit log with validations'`** - Tests required field validations
- **`'an audit log with user tracking'`** - Tests user login and impersonation logging
- **`'an audit log with AI tracking'`** - Tests AI output review logging
- **`'an audit log with formatting'`** - Tests metadata formatting and time display
- **`'an audit log with resource tracking'`** - Tests resource creation/update/deletion logging

#### Usage Example:

```ruby
RSpec.describe MyAuditLogModel do
  include_examples 'an audit logger'
  include_examples 'an audit log with scopes'
  include_examples 'an audit log with validations'
  include_examples 'an audit log with user tracking'
  include_examples 'an audit log with AI tracking'
  include_examples 'an audit log with formatting'
  include_examples 'an audit log with resource tracking'
end
```

#### Required Class Methods:

- `create_log(user:, action:, description:, ...)` - Creates audit log entry
- `log_login(user, ip_address:, user_agent:)` - Logs user login
- `log_impersonation(admin_user, target_user, action, ...)` - Logs impersonation events
- `log_ai_review(user, ai_output, rating, ...)` - Logs AI output reviews
- `recent` - Scope for recent logs
- `for_action(action)` - Scope for specific action
- `for_resource_type(type)` - Scope for specific resource type
- `for_user(user_id)` - Scope for specific user

#### Required Instance Methods:

- `formatted_metadata` - Returns formatted metadata string
- `time_ago` - Returns human-readable time difference

#### Required Attributes:

- `user` - Associated user (can be nil for system actions)
- `action` - Action being logged
- `description` - Human-readable description
- `resource_type` - Type of resource being tracked (optional)
- `resource_id` - ID of resource being tracked (optional)
- `metadata` - Hash of additional data (optional)
- `ip_address` - IP address of action (optional)
- `user_agent` - User agent string (optional)

## Best Practices

1. **Use selectively** - Only include the shared examples that apply to your model
2. **Add module-specific tests** - Shared examples cover common patterns, but add tests for unique functionality
3. **Follow naming conventions** - Keep method and attribute names consistent with the patterns
4. **Document deviations** - If your model doesn't fully match the pattern, document why

## Example Module Structure

When creating a new module, consider this test structure:

```
spec/
  models/
    my_module/
      my_prompt_model_spec.rb  # Uses llm_prompt shared examples
      my_audit_log_spec.rb     # Uses audit_logger shared examples
```

This ensures consistent testing patterns while allowing for module-specific customization.