# MCP (Multi-Context Provider) Per Workspace

This feature allows workspaces to define what data sources and context fetchers their AI agents have access to. It provides a flexible system for managing context providers on both global and workspace-specific levels.

## Features Implemented

### Core Models

- **McpFetcher**: Registry of available context providers with configuration
- **WorkspaceMcpFetcher**: Join table for workspace-specific fetcher configuration
- **Workspace**: Basic workspace model with MCP relationships
- **McpWorkspaceService**: Service for managing workspace-specific context fetching

### Admin Interface

- Complete CRUD interface for managing MCP fetchers
- Workspace-specific enable/disable toggles
- JSON configuration management with validation
- Real-time status display (inherited vs. workspace-override)
- Audit logging integration

### Key Capabilities

1. **Global Configuration**: Set default availability of fetchers across all workspaces
2. **Workspace Overrides**: Enable/disable specific fetchers per workspace
3. **Configuration Management**: JSON-based configuration with validation
4. **Audit Logging**: Complete audit trail of all fetcher changes
5. **Sample Output**: Documentation and debugging support

## Database Schema

### MCP Fetchers Table
```sql
CREATE TABLE mcp_fetchers (
  id BIGINT PRIMARY KEY,
  name VARCHAR NOT NULL UNIQUE,
  description TEXT,
  provider_type VARCHAR NOT NULL,
  configuration JSON DEFAULT '{}',
  parameters JSON DEFAULT '{}',
  sample_output TEXT,
  enabled BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Workspace MCP Fetchers Join Table
```sql
CREATE TABLE workspace_mcp_fetchers (
  id BIGINT PRIMARY KEY,
  workspace_id BIGINT NOT NULL REFERENCES workspaces(id),
  mcp_fetcher_id BIGINT NOT NULL REFERENCES mcp_fetchers(id),
  enabled BOOLEAN DEFAULT TRUE NOT NULL,
  workspace_configuration JSON DEFAULT '{}',
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(workspace_id, mcp_fetcher_id)
);
```

## Usage Examples

### Creating an MCP Fetcher

```ruby
# Database query fetcher
database_fetcher = McpFetcher.create!(
  name: 'user_analytics',
  provider_type: 'database',
  description: 'Fetch user engagement metrics',
  configuration: {
    query: 'SELECT COUNT(*) as active_users, AVG(session_duration) as avg_duration FROM user_sessions WHERE workspace_id = ?',
    timeout: 30
  },
  parameters: {
    workspace_id: 'required',
    date_range: 'optional'
  },
  sample_output: '{"active_users": 150, "avg_duration": 245.5}',
  enabled: true
)

# API fetcher
api_fetcher = McpFetcher.create!(
  name: 'slack_integration',
  provider_type: 'http_api',
  description: 'Fetch team communication data from Slack',
  configuration: {
    url: 'https://slack.com/api/conversations.history',
    headers: { 'Authorization' => 'Bearer xoxb-your-token' },
    timeout: 60
  },
  parameters: {
    channel: 'required',
    limit: 50
  },
  sample_output: '{"messages": [...], "has_more": false}',
  enabled: true
)
```

### Using the Workspace Service

```ruby
# Create service for specific workspace
service = McpWorkspaceService.new(workspace)

# Fetch context data
user_data = service.fetch(:user_analytics, {
  fetcher_name: 'user_analytics',
  params: { workspace_id: workspace.id, date_range: '7d' }
})

slack_data = service.fetch(:team_communication, {
  fetcher_name: 'slack_integration',
  params: { channel: 'general', limit: 20 }
})

# Access all context
context = service.to_h
# => {
#   user_analytics: { active_users: 150, avg_duration: 245.5 },
#   team_communication: { messages: [...], has_more: false }
# }

# Get JSON for AI prompt
json_context = service.to_json
```

### Workspace-Specific Configuration

```ruby
# Check if fetcher is enabled for workspace
workspace.mcp_fetcher_enabled?(database_fetcher)
# => true (inherits global setting)

# Toggle fetcher for specific workspace
database_fetcher.toggle_for_workspace!(workspace)

# Check status
database_fetcher.workspace_status(workspace)
# => "Disabled for Workspace"

# Get workspace-specific configuration
config = database_fetcher.workspace_configuration_for(workspace)
```

## Admin Interface Usage

### Accessing the Admin Panel

1. Navigate to `/admin/mcp_fetchers`
2. View all available fetchers with their global status
3. Create new fetchers using the "New Fetcher" button
4. Edit existing fetchers to modify configuration

### Managing Workspace Overrides

1. On the fetcher detail page, expand "Workspace Configuration"
2. Use enable/disable buttons for each workspace
3. Status shows: "Inherited (Enabled)", "Disabled for Workspace", etc.
4. Changes are immediately audited and logged

### Configuration Management

- **Provider Types**: database, http_api, file, custom
- **Configuration**: JSON object with provider-specific settings
- **Parameters**: JSON schema for runtime parameters
- **Sample Output**: Example output for documentation

## Provider Types

### Database Provider
```json
{
  "query": "SELECT * FROM table WHERE condition = ?",
  "timeout": 30,
  "retries": 3
}
```

### HTTP API Provider
```json
{
  "url": "https://api.example.com/endpoint",
  "method": "GET",
  "headers": {
    "Authorization": "Bearer token",
    "Content-Type": "application/json"
  },
  "timeout": 60
}
```

### File Provider
```json
{
  "path": "/data/context.json",
  "format": "json",
  "encoding": "utf-8"
}
```

## Security Considerations

1. **SQL Injection Protection**: Database queries use parameterized statements
2. **Authentication**: API fetchers support various auth methods
3. **Audit Logging**: All configuration changes are logged
4. **Access Control**: Admin-only access to fetcher management
5. **Validation**: JSON configuration is validated before saving

## Audit Logging

All MCP-related activities are logged:

- Fetcher creation, updates, deletion
- Global enable/disable actions
- Workspace-specific toggles
- Context fetch operations (success/failure)
- Configuration changes

Example audit entry:
```ruby
{
  user_id: 123,
  action: 'toggle_workspace',
  resource_type: 'McpFetcher',
  resource_id: 456,
  description: 'Enabled MCP fetcher: user_analytics for workspace: Engineering Team',
  metadata: {
    workspace_id: 789,
    workspace_name: 'Engineering Team',
    fetcher_name: 'user_analytics'
  },
  timestamp: '2024-01-15T10:30:00Z'
}
```

## Integration with AI Systems

The MCP system is designed to integrate with AI agents and prompt systems:

```ruby
# In your AI prompt processing
service = McpWorkspaceService.new(current_workspace)

# Load relevant context
service.fetch(:user_data, { fetcher_name: 'user_analytics' })
service.fetch(:recent_activity, { fetcher_name: 'activity_feed' })

# Include in prompt
prompt = PromptTemplate.new(
  template: "Based on this context: #{service.to_json}\n\nAnalyze user engagement...",
  context: service.to_h
)
```

## Testing

The implementation includes comprehensive tests:

- Unit tests for all models (`test/models/`)
- Service tests with mocks (`test/models/simple_mcp_workspace_service_test.rb`)
- Integration tests demonstrating full workflow (`test/integration/`)

Run tests:
```bash
ruby test/models/mcp_fetcher_test.rb
ruby test/models/simple_mcp_workspace_service_test.rb
ruby test/integration/mcp_workspace_integration_test.rb
```

## Future Enhancements

Potential areas for expansion:

1. **API Endpoints**: RESTful API for programmatic access
2. **Caching**: Redis-based caching for frequently accessed context
3. **Rate Limiting**: Protect external APIs from overuse
4. **Monitoring**: Metrics and alerting for fetcher performance
5. **Versioning**: Version control for fetcher configurations
6. **Templates**: Predefined fetcher templates for common use cases

## File Structure

```
app/
├── controllers/admin/
│   └── mcp_fetchers_controller.rb       # Admin CRUD controller
├── models/
│   ├── mcp_fetcher.rb                   # Core fetcher model
│   ├── workspace_mcp_fetcher.rb         # Join model
│   ├── workspace.rb                     # Workspace model with MCP relations
│   └── mcp_workspace_service.rb         # Context fetching service
└── views/admin/mcp_fetchers/
    ├── index.html.erb                   # Fetcher listing
    ├── show.html.erb                    # Fetcher details
    ├── new.html.erb                     # Creation form
    └── edit.html.erb                    # Edit form

db/migrate/
├── 002_create_workspaces.rb            # Basic workspace table
├── 006_create_mcp_fetchers.rb          # MCP fetcher registry
└── 007_create_workspace_mcp_fetchers.rb # Join table

test/
├── models/
│   ├── mcp_fetcher_test.rb             # Model unit tests
│   └── simple_mcp_workspace_service_test.rb # Service tests
└── integration/
    └── mcp_workspace_integration_test.rb # Full workflow tests
```

This implementation provides a solid foundation for workspace-specific context management while maintaining the flexibility to extend and customize based on specific AI use cases.