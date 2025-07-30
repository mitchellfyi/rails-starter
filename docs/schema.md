# Database Schema

This document describes the database schema for the application.

## Models Overview


- **ApplicationRecord**: 0 validations
- **AuditLog**: 2 validations
- **AdminUserExtensions**: 0 validations
- **FeatureFlag**: 2 validations
- **McpFetcher**: 4 validations
- **McpWorkspaceService**: 0 validations
- **Notification**: 0 validations
- **SystemPrompt**: 5 validations
- **User**: 2 validations
- **Workspace**: 3 validations
- **WorkspaceFeatureFlag**: 1 validations
- **WorkspaceMcpFetcher**: 1 validations

## Model Details

### ApplicationRecord


### AuditLog

**Validations:**
- `action`: presence: true
- `description`: presence: true

**Associations:**
- `belongs_to` user

**Scopes:**
- `recent`
- `for_action`
- `for_resource_type`
- `for_user`

### AdminUserExtensions


**Associations:**
- `has_many` audit_logs

### FeatureFlag

**Validations:**
- `name`: presence: true, uniqueness: true
- `description`: presence: true

**Associations:**
- `has_many` workspace_feature_flags

**Scopes:**
- `active`
- `inactive`

### McpFetcher

**Validations:**
- `name`: presence: true, uniqueness: true
- `provider_type`: presence: true
- `description`: presence: true
- `configuration_is_valid_json`: validate :parameters_is_valid_json

**Associations:**
- `has_many` workspace_mcp_fetchers
- `has_many` workspaces

**Scopes:**
- `enabled`
- `disabled`
- `by_provider_type`

### McpWorkspaceService


### Notification


**Associations:**
- `belongs_to` recipient

**Scopes:**
- `unread`
- `read`
- `recent`
- `for_type`

### SystemPrompt

**Validations:**
- `name`: presence: true, uniqueness: { scope: :workspace_id }
- `slug`: presence: true, uniqueness: { scope: :workspace_id }, format: { with: /\A[a-z0-9_-]+\z/ }
- `prompt_text`: presence: true
- `status`: presence: true, inclusion: { in: %w[draft active archived] }
- `version`: presence: true, format: { with: /\A\d+\.\d+\.\d+\z/ }

**Associations:**
- `belongs_to` workspace
- `belongs_to` created_by

**Scopes:**
- `active`
- `global`
- `for_workspace`
- `by_role`
- `by_function`
- `by_agent`

### User

**Validations:**
- `email`: presence: true, uniqueness: true
- `email`: format: { with: URI::MailTo::EMAIL_REGEXP }

### Workspace

**Validations:**
- `name`: presence: true
- `monthly_ai_credit`: numericality: { greater_than_or_equal_to: 0 }
- `current_month_usage`: numericality: { greater_than_or_equal_to: 0 }

**Associations:**
- `has_many` workspace_feature_flags
- `has_many` feature_flags
- `has_many` workspace_mcp_fetchers
- `has_many` mcp_fetchers
- `has_many` ai_routing_policies
- `has_many` llm_outputs
- `has_many` llm_usage
- `has_one` workspace_spending_limit

### WorkspaceFeatureFlag

**Validations:**
- `workspace_id`: uniqueness: { scope: :feature_flag_id }

**Associations:**
- `belongs_to` workspace
- `belongs_to` feature_flag

### WorkspaceMcpFetcher

**Validations:**
- `workspace_id`: uniqueness: { scope: :mcp_fetcher_id }

**Associations:**
- `belongs_to` workspace
- `belongs_to` mcp_fetcher

**Scopes:**
- `enabled`
- `disabled`


## Relationships

- AuditLog `belongs_to` user
- AdminUserExtensions `has_many` audit_logs
- FeatureFlag `has_many` workspace_feature_flags
- McpFetcher `has_many` workspace_mcp_fetchers
- McpFetcher `has_many` workspaces
- Notification `belongs_to` recipient
- SystemPrompt `belongs_to` workspace
- SystemPrompt `belongs_to` created_by
- Workspace `has_many` workspace_feature_flags
- Workspace `has_many` feature_flags
- Workspace `has_many` workspace_mcp_fetchers
- Workspace `has_many` mcp_fetchers
- Workspace `has_many` ai_routing_policies
- Workspace `has_many` llm_outputs
- Workspace `has_many` llm_usage
- Workspace `has_one` workspace_spending_limit
- WorkspaceFeatureFlag `belongs_to` workspace
- WorkspaceFeatureFlag `belongs_to` feature_flag
- WorkspaceMcpFetcher `belongs_to` workspace
- WorkspaceMcpFetcher `belongs_to` mcp_fetcher
