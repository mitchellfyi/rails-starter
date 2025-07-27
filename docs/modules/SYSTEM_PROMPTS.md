# System Prompts Feature Documentation

## Overview

The System Prompts feature allows teams to define reusable, versioned system prompts for AI agents, with support for both global and workspace-specific prompts.

## Key Features

### 1. **Versioned Prompts**
- Each system prompt has a semantic version (e.g., "1.0.0", "1.0.1")
- Create new versions without losing previous ones
- Compare differences between versions
- Activate specific versions

### 2. **Workspace Scoping**
- **Global Prompts**: Available to all workspaces as fallback
- **Workspace-Specific Prompts**: Override global prompts for specific workspaces
- Automatic fallback to global prompts when workspace-specific ones don't exist

### 3. **Association System**
- Associate prompts with **roles** (e.g., "support", "sales", "developer")
- Associate prompts with **functions** (e.g., "chat_support", "code_review")  
- Associate prompts with **agents** (e.g., "support_bot_v1", "sales_assistant")

### 4. **Status Management**
- **Draft**: Work-in-progress prompts
- **Active**: Currently used prompts
- **Archived**: Deprecated prompts

### 5. **Variable Support**
- Use `{{variable_name}}` syntax for dynamic content
- Automatic variable extraction and validation
- Context rendering for personalized prompts

## Usage

### Creating System Prompts

#### Global Prompt (Available to All Workspaces)
```ruby
SystemPrompt.create!(
  name: "Customer Support Assistant",
  prompt_text: "You are a helpful customer support agent for {{company_name}}...",
  description: "Standard customer support prompt",
  status: "active",
  workspace: nil, # Global prompt
  associated_roles: ["support", "customer_service"],
  associated_functions: ["chat_support", "ticket_handling"]
)
```

#### Workspace-Specific Prompt
```ruby
workspace = Workspace.find_by(slug: "my-workspace")
SystemPrompt.create!(
  name: "Sales Assistant", 
  prompt_text: "You are a sales assistant for {{company_name}}...",
  description: "Workspace-specific sales prompt",
  status: "active",
  workspace: workspace,
  associated_roles: ["sales"],
  associated_functions: ["lead_qualification"]
)
```

### Finding the Right Prompt

Use the `find_for_workspace` method with automatic fallback:

```ruby
# Find best prompt for a workspace with role filtering
prompt = SystemPrompt.find_for_workspace(
  workspace, 
  role: "support"
)

# Falls back to global if no workspace-specific prompt exists
prompt = SystemPrompt.find_for_workspace(
  workspace,
  function: "chat_support" 
)
```

### Rendering Prompts with Variables

```ruby
context = {
  "company_name" => "Acme Corp",
  "user_name" => "John Doe"
}

rendered = prompt.render_with_context(context)
# "You are a helpful customer support agent for Acme Corp..."
```

### Version Management

```ruby
# Create a new version
new_version = prompt.create_new_version!(
  description: "Enhanced with new capabilities"
)

# Activate a version (deactivates others)
new_version.activate!

# Get version history
prompt.version_history

# Compare versions
diff = prompt.diff_with_version(previous_version_id)
```

### Cloning Prompts

```ruby
# Clone within same workspace
cloned = prompt.clone!("New Prompt Name")

# Clone to different workspace
target_workspace = Workspace.find_by(slug: "other-workspace")
cloned = prompt.clone!("Cross-Workspace Prompt", target_workspace)
```

## Web Interface

### Navigation
- **Global Prompts**: `/system_prompts`
- **Workspace Prompts**: `/system_prompts?workspace_id=123`

### Key Actions
- **Create**: New system prompt form
- **Edit**: Modify existing prompts
- **Activate**: Make a version active
- **Clone**: Copy prompts within/across workspaces
- **New Version**: Create versioned copies
- **Diff**: Compare changes between versions

## Database Schema

```sql
CREATE TABLE system_prompts (
  id bigint PRIMARY KEY,
  name varchar NOT NULL,
  slug varchar NOT NULL,
  description text,
  prompt_text text NOT NULL,
  status varchar DEFAULT 'draft' NOT NULL,
  workspace_id bigint, -- NULL for global prompts
  created_by_id bigint,
  version varchar DEFAULT '1.0.0',
  associated_roles varchar[] DEFAULT '{}',
  associated_functions varchar[] DEFAULT '{}', 
  associated_agents varchar[] DEFAULT '{}',
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);

-- Key indexes for performance
CREATE UNIQUE INDEX ON system_prompts (workspace_id, name);
CREATE UNIQUE INDEX ON system_prompts (workspace_id, slug);
CREATE INDEX ON system_prompts (status);
CREATE INDEX ON system_prompts USING GIN (associated_roles);
CREATE INDEX ON system_prompts USING GIN (associated_functions);
CREATE INDEX ON system_prompts USING GIN (associated_agents);
```

## Best Practices

### 1. **Naming Conventions**
- Use descriptive names: "Customer Support Assistant" vs "Prompt 1"
- Include purpose: "Sales Lead Qualification Bot"
- Version in description, not name

### 2. **Variable Usage**  
- Use clear variable names: `{{customer_name}}` vs `{{x}}`
- Document expected variables in description
- Provide fallback values when possible

### 3. **Association Strategy**
- **Roles**: Broad categories ("support", "sales", "developer")
- **Functions**: Specific use cases ("lead_qualification", "code_review") 
- **Agents**: Specific bot instances ("support_bot_v2")

### 4. **Workspace Strategy**
- Start with global prompts for common use cases
- Create workspace-specific prompts only when needed
- Use workspace prompts for company-specific tone/branding

### 5. **Version Management**
- Keep versions focused (single feature/improvement)
- Test thoroughly before activating
- Document changes in description
- Archive old versions rather than deleting

## Integration Examples

### With AI Service
```ruby
class AIService
  def generate_response(workspace, user_input, role: nil)
    # Find appropriate system prompt
    system_prompt = SystemPrompt.find_for_workspace(
      workspace, 
      role: role
    )
    
    # Render with context
    context = {
      "company_name" => workspace.name,
      "user_name" => current_user.name
    }
    rendered_prompt = system_prompt.render_with_context(context)
    
    # Use with AI model
    openai_client.chat(
      messages: [
        { role: "system", content: rendered_prompt },
        { role: "user", content: user_input }
      ]
    )
  end
end
```

### With Job Queue
```ruby
class ProcessChatJob < ApplicationJob
  def perform(workspace_id, user_message, role)
    workspace = Workspace.find(workspace_id)
    
    system_prompt = SystemPrompt.find_for_workspace(
      workspace,
      role: role
    )
    
    # Process with system prompt...
  end
end
```

This system provides a flexible, scalable way to manage AI system prompts across different contexts while maintaining version control and workspace isolation.