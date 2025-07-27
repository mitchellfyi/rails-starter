# Token Usage & Cost Tracking

This module provides comprehensive tracking and management of AI-related usage costs, billing, and rate limiting for workspaces.

## Features

### 1. LLMUsage Model - Aggregated Usage Tracking

The `LlmUsage` model stores aggregated daily usage data by workspace, provider, and model:

- **Fields**: workspace_id, provider, model, prompt_tokens, completion_tokens, total_tokens, cost, date, request_count
- **Aggregation**: Automatically aggregates from `LLMOutput` records daily
- **Analytics**: Provides methods for usage stats, trends, and top models

**Key Methods:**
```ruby
# Aggregate usage for a specific date
LlmUsage.aggregate_for_date(Date.current - 1.day)

# Get workspace stats for date range
LlmUsage.stats_for_workspace(workspace, start_date: 30.days.ago, end_date: Date.current)

# Get usage trends
LlmUsage.usage_trend_for_workspace(workspace, days: 30)

# Get top models by cost
LlmUsage.top_models_for_workspace(workspace, limit: 10)
```

### 2. Monthly Credits & Overage Billing

Workspaces now have built-in credit management:

**Workspace Fields:**
- `monthly_ai_credit` - Free credit amount per month (default: $10)
- `current_month_usage` - Current month's usage amount
- `usage_reset_date` - Date when usage was last reset
- `overage_billing_enabled` - Whether to bill for usage above credits
- `stripe_meter_id` - Stripe meter ID for overage billing

**Key Methods:**
```ruby
workspace = Workspace.find(1)

# Check credit status
workspace.remaining_monthly_credit  # => 75.0
workspace.credit_exhausted?         # => false
workspace.usage_percentage          # => 25.0

# Add usage (automatically resets monthly if needed)
workspace.add_usage!(5.0)

# Get usage summary
workspace.usage_summary
# => {
#   monthly_credit: 100.0,
#   current_usage: 25.0,
#   remaining_credit: 75.0,
#   usage_percentage: 25.0,
#   credit_exhausted: false,
#   overage_billing_enabled: true,
#   this_month: { cost: 25.0, tokens: 50000, requests: 100 }
# }
```

### 3. Rate Limiting

Enhanced `WorkspaceSpendingLimit` model with request rate limiting:

**New Fields:**
- `rate_limit_enabled` - Enable rate limiting
- `requests_per_minute` - Max requests per minute
- `requests_per_hour` - Max requests per hour  
- `requests_per_day` - Max requests per day
- `block_when_rate_limited` - Whether to block or just warn

**Usage:**
```ruby
limit = workspace.workspace_spending_limit
limit.update!(
  rate_limit_enabled: true,
  requests_per_minute: 10,
  requests_per_hour: 100,
  requests_per_day: 1000,
  block_when_rate_limited: true
)

# Check if request would be rate limited
limit.would_be_rate_limited?  # => false

# Add a request (automatically tracks counts)
limit.add_request!

# Check rate limit status
limit.rate_limit_exceeded?    # => false
limit.minute_exceeded?        # => false
```

### 4. Enhanced Usage Dashboard

#### Admin Dashboard (`/admin/usage`)
- Workspace usage stats with cost tracking
- Top models by cost
- Daily usage trends with cost data
- Provider breakdown
- Credit overview across all workspaces
- Most expensive workspaces

#### Workspace Dashboard (`/workspace_usage/:workspace_id`)
- Monthly credit usage and remaining balance
- Usage percentage with visual progress bars
- Usage trends and top models for the workspace
- Recent high-cost requests
- Spending limit status (if configured)
- Rate limiting status
- Alerts for approaching limits

### 5. Background Jobs

#### AggregateUsageJob
Runs daily to aggregate `LLMOutput` records into `LlmUsage` summaries:

```ruby
# Run for specific date
AggregateUsageJob.perform_later(Date.current - 1.day)

# Run for yesterday (default)
AggregateUsageJob.perform_later
```

**Scheduling**: Add to your scheduler (cron, whenever, etc.):
```ruby
# config/schedule.rb (if using whenever gem)
every 1.day, at: '2:00 am' do
  runner "AggregateUsageJob.perform_later"
end
```

### 6. LLMJob Integration

The `LLMJob` now includes:
- Rate limiting checks before processing
- Automatic workspace usage tracking
- Request counting for rate limits

When a job runs:
1. Checks rate limits (blocks if exceeded and configured to block)
2. Records request attempt for rate limiting
3. Processes LLM request
4. Updates workspace usage via `LLMOutput#update_actual_cost!`

## Database Migrations

Run these migrations to set up the new features:

```bash
# Create LLM usage aggregation table
rails db:migrate VERSION=20241217000008

# Add monthly credits to workspaces
rails db:migrate VERSION=20241217000009

# Add rate limiting to workspace spending limits
rails db:migrate VERSION=20241217000010
```

## Configuration

### 1. Set Default Monthly Credits

In your workspace creation logic:

```ruby
workspace = Workspace.create!(
  name: 'My Workspace',
  monthly_ai_credit: 50.0  # $50 monthly credit
)
```

### 2. Enable Overage Billing

```ruby
workspace.update!(
  overage_billing_enabled: true,
  stripe_meter_id: 'stripe_meter_xyz'  # Set after creating Stripe meter
)
```

### 3. Configure Rate Limiting

```ruby
WorkspaceSpendingLimit.create!(
  workspace: workspace,
  created_by: user,
  updated_by: user,
  rate_limit_enabled: true,
  requests_per_minute: 10,
  requests_per_hour: 100,
  requests_per_day: 1000,
  block_when_rate_limited: true
)
```

## Monitoring & Alerts

### Usage Warnings

The system automatically detects:
- Monthly credit usage > 80% (warning) or > 95% (danger)
- Spending limit approaches (daily/weekly/monthly)
- Rate limit approaches

### Logging

All usage events are logged:
- Rate limit violations
- Credit exhaustion
- Overage billing events
- Failed aggregation jobs

## API Integration

### Stripe Metered Billing

When overage billing is enabled, the system can integrate with Stripe's metered billing:

1. Create a Stripe meter for AI usage overages
2. Set the `stripe_meter_id` on the workspace
3. The system will automatically report overage usage to Stripe

**Note**: Stripe integration is prepared but requires actual Stripe API implementation in `Workspace#report_overage_to_stripe`.

## Best Practices

1. **Set Reasonable Credits**: Start with $10-50 monthly credits per workspace
2. **Monitor Usage**: Review the admin dashboard weekly
3. **Configure Alerts**: Set up email notifications for credit exhaustion
4. **Rate Limiting**: Use rate limiting for workspaces with many users
5. **Data Retention**: The aggregation job keeps 2 years of usage data
6. **Daily Aggregation**: Ensure the aggregation job runs daily for accurate reporting

## Troubleshooting

### Missing Usage Data
- Check if `AggregateUsageJob` is running daily
- Verify `LLMOutput` records have `workspace_id` set
- Check job logs for aggregation errors

### Rate Limiting Issues
- Verify rate limits are reasonable for workspace usage
- Check `last_request_time` is updating correctly
- Review rate limit reset logic

### Credit Tracking
- Ensure `usage_reset_date` is updated monthly
- Verify `add_usage!` is called when costs are updated
- Check for proper month boundary handling

## Testing

The module includes comprehensive tests:
- `LlmUsageTest` - Model validation and aggregation
- `WorkspaceUsageTest` - Credit management
- `WorkspaceSpendingLimitRateLimitingTest` - Rate limiting
- `AggregateUsageJobTest` - Background job functionality

Run tests with:
```bash
ruby test_token_usage_implementation.rb
```