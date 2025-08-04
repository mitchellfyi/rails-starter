# Schema-Aware Chat Interface

The RailsPlan chat interface provides an intelligent, schema-aware AI assistant that can help developers understand their Rails application structure, query their database safely, and generate code.

## Features

### 🧠 Schema Awareness
- Understands your database schema (tables, columns, indexes, constraints)
- Knows about ActiveRecord models and their associations
- Aware of routes, controllers, and application structure
- Provides context-aware suggestions and responses

### 🔒 Safe Database Queries
- Read-only query execution with strict validation
- SQL injection prevention
- Configurable query limits (default: 100 rows max)
- Audit logging for all data access
- User confirmation for query execution

### 💬 Interactive Chat
- Natural language questions about your app
- Real-time streaming responses
- Query suggestions based on your schema
- Data mode for database-related questions
- Recent query history

## Usage

### Accessing the Chat Interface

```bash
# In any RailsPlan-generated Rails application:
bin/rails server
# Visit: http://localhost:3000/railsplan/chat
```

### Example Questions

**Schema & Structure:**
- "What models do I have in my application?"
- "Show me the schema for my database tables"
- "How are my User and Order models related?"
- "What validations does the User model have?"

**Data Exploration:**
- "Show me sample data from the users table"
- "How many orders were created this week?"
- "What are the most common user statuses?"
- "Find users who haven't logged in recently"

**Code Generation:**
- "Generate a migration to add a status field to users"
- "Create a scope for active users"
- "Write a validation for email uniqueness"

## Configuration

Configure the chat interface in `.railsplan/ai.yml`:

```yaml
# Database query execution settings
allow_query_execution: true
max_query_limit: 100
require_confirmation: true

# AI provider settings
default_provider: openai
max_tokens: 4000

# Security settings  
audit_data_access: true
forbidden_keywords:
  - DROP
  - DELETE
  - UPDATE
  - INSERT
```

## Security

### Query Safety
- Only `SELECT` statements are allowed
- All DML operations (INSERT/UPDATE/DELETE/DROP) are blocked
- SQL injection patterns are detected and prevented
- Query results are limited to prevent large data dumps

### Audit Logging
- All chat interactions are logged to `.railsplan/prompts.log`
- Database queries are logged to `.railsplan/ai_data_access.log`
- Includes timestamp, query, user agent, and IP address

### Access Control
- Only available in RailsPlan-generated applications
- Requires `.railsplan/context.json` to be present
- Can be disabled by setting `allow_query_execution: false`

## API Endpoints

The chat interface provides several endpoints:

```ruby
GET  /railsplan/chat           # Main chat interface
POST /railsplan/chat           # Process chat messages  
GET  /railsplan/chat/preview   # Preview database queries
POST /railsplan/chat/explain   # Explain SQL queries
GET  /railsplan/schema         # Get schema summary
```

## Integration with CLI

The web chat interface complements the existing CLI chat:

```bash
# CLI chat (existing)
railsplan chat "Explain my User model"

# Web chat (new)
# Visit /railsplan/chat in browser
```

## Troubleshooting

### Chat Interface Not Loading
- Ensure you're in a RailsPlan-generated Rails app
- Check that `.railsplan/context.json` exists
- Run `railsplan index` to regenerate context

### Database Queries Not Working
- Check `allow_query_execution` in `.railsplan/ai.yml`
- Ensure ActiveRecord models are loaded
- Verify database connection is working

### AI Responses Are Generic
- Run `railsplan index` to refresh application context
- Check that schema parsing is working correctly
- Verify AI provider configuration

## Development

### Adding New Query Types
Extend the `RailsPlan::DataPreview` service:

```ruby
# Add custom query methods
def count_by_status(model_name)
  # Implementation
end
```

### Customizing Suggestions
Modify the `schema_aware_suggestions` method in `RailsplanChatController`:

```ruby
def schema_aware_suggestions
  # Add custom suggestions based on your app
end
```

### Enhanced Schema Parsing
Extend `RailsPlan::ContextManager` to extract additional information:

```ruby
def extract_custom_metadata
  # Parse custom annotations, etc.
end
```