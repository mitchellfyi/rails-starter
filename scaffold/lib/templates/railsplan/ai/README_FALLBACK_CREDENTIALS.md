# Fallback AI Credentials

This feature allows site administrators to provide shared API keys that new users can use to try AI features without needing their own API keys first.

## Overview

The fallback credentials system extends the existing `AiCredential` model with a `is_fallback` flag and related functionality. When users don't have their own AI credentials configured, the system can automatically fall back to admin-provided shared credentials.

## Key Features

- **Admin Management**: Simple admin interface for creating and managing fallback credentials
- **Automatic Fallback**: Transparent fallback when users don't have their own credentials
- **Usage Tracking**: Track total usage and optionally set limits
- **Expiration Support**: Optional expiration dates for time-limited trials
- **Onboarding Integration**: UI components to promote trial access during onboarding

## Database Schema

The feature adds these fields to the existing `ai_credentials` table:

```ruby
add_column :ai_credentials, :is_fallback, :boolean, default: false, null: false
add_column :ai_credentials, :fallback_usage_limit, :integer
add_column :ai_credentials, :fallback_usage_count, :integer, default: 0, null: false
add_column :ai_credentials, :expires_at, :datetime
add_column :ai_credentials, :onboarding_message, :text
add_column :ai_credentials, :enabled_for_trials, :boolean, default: true, null: false
```

## Usage

### Admin Interface

Administrators can manage fallback credentials through the admin interface:

- **Create**: `/admin/fallback-credentials/new`
- **List**: `/admin/fallback-credentials`
- **Edit**: `/admin/fallback-credentials/:id/edit`
- **View**: `/admin/fallback-credentials/:id`

### Programmatic Access

```ruby
# Check if fallback credentials are available
AiCredential.fallback_enabled?

# Get the best available credential (falls back to admin credentials if no user credentials)
credential = AiCredential.best_for(workspace, 'openai')

# Get best fallback credential for a provider
fallback = AiCredential.best_fallback_for_provider('openai')

# Check if a credential is available for use
credential.available?

# Track usage
credential.mark_used!
```

### Onboarding Component

Include the trial access component in your onboarding views:

```erb
<%= render 'shared/trial_ai_access', provider: 'openai', workspace: current_workspace %>
```

## Configuration

### Creating Fallback Credentials

Fallback credentials are regular AI credentials with special properties:

- `is_fallback: true`
- `workspace: nil` (not associated with any workspace)
- `enabled_for_trials: true` (available for trial users)

### Usage Limits

Set optional limits to control trial usage:

- **Usage Limit**: Total number of API calls allowed
- **Expiration Date**: When the credential stops working
- **Daily Limits**: Could be added in the future if needed

### Onboarding Messages

Customize the message shown to users during onboarding by setting the `onboarding_message` field.

## Examples

### Admin Creating a Fallback Credential

```ruby
AiCredential.create!(
  name: "OpenAI Trial Access",
  ai_provider: openai_provider,
  api_key: "sk-...",
  preferred_model: "gpt-3.5-turbo",
  is_fallback: true,
  workspace: nil,
  active: true,
  enabled_for_trials: true,
  fallback_usage_limit: 100,
  expires_at: 30.days.from_now,
  onboarding_message: "Try our AI assistant with 100 free credits!"
)
```

### User Accessing AI Features

When a user tries to use AI features, the system automatically:

1. Looks for user's own credentials first
2. Falls back to available admin credentials if none found
3. Returns `nil` if no credentials are available

```ruby
# This will automatically use fallback credentials if user has none
credential = AiCredential.best_for(current_workspace, 'openai')

if credential
  # Use the credential (could be user's own or fallback)
  result = ai_service.call(credential.full_config)
  credential.mark_used! # Track usage
else
  # No credentials available - prompt user to add their own
end
```

## Security Considerations

- Fallback credentials are encrypted the same way as regular credentials
- Admin interface should be properly authenticated and authorized
- Usage tracking helps monitor and prevent abuse
- Expiration dates provide automatic cleanup

## Future Enhancements

Potential improvements for the future:

- Daily usage limits per user
- More detailed usage analytics
- User-specific usage tracking
- Admin dashboard with usage charts
- Webhook notifications for usage milestones
- Rate limiting integration