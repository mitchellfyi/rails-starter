# Admin Panel Module

This module adds a comprehensive admin panel to your Rails SaaS application with advanced administrative features for user management, system monitoring, feature control, and user activity tracking.

## Features

### 🎭 User Impersonation
- **Safe impersonation:** Admins can impersonate users for support and testing
- **Session management:** Clear sign-out and revert-to-admin safeguards
- **Audit trail:** All impersonation activities are logged

### 📊 Enhanced Audit Logs
- **Comprehensive tracking:** Records changes to critical resources (users, billing, content, prompts)
- **Advanced filtering:** Filter by resource type, event type, admin user, workspace, and date range
- **Search functionality:** Full-text search across audit log data
- **Export capabilities:** CSV and JSON export with applied filters
- **Detailed metadata:** Captures before/after states, IP addresses, user agents

### 📈 User Activity Feed
- **Personal activity tracking:** Each user has their own activity timeline
- **Timeline UI:** Beautiful, chronological display of user actions
- **Rich filtering:** Filter by workspace, date range, event type, and resource type
- **Activity types:** Tracks invitations, subscriptions, blog posts, logins, and more
- **Admin oversight:** Admins can view all user activities across the platform

### 🔧 Sidekiq Management
- **Integrated UI:** Sidekiq Web UI mounted within the admin panel
- **Secure access:** Authentication and authorization tied to admin roles
- **Job monitoring:** Real-time queue monitoring and job management

### 🚩 Feature Flag Management
- **Flipper integration:** Simple interface for toggling experimental features
- **Environment controls:** Manage feature flags per environment
- **User targeting:** Enable features for specific users or groups

## Installation

Run the following command from your application root to install the admin module:

```bash
bin/synth add admin
```

This command will:
- Add necessary gems to your Gemfile
- Generate admin controllers and views
- Create audit log and user activity models with migrations
- Set up authentication and authorization
- Configure Sidekiq UI mounting
- Install Flipper for feature flag management
- Add comprehensive test coverage
- Create user activity feed for end users

## Configuration

After installation, configure admin access by:

1. **Setting admin roles:** Update your User model to include admin privileges
2. **Configuring feature flags:** Set up initial feature flags in the Flipper dashboard
3. **Customizing audit rules:** Define which models and actions should be audited
4. **Activity tracking:** Include the `ActivityTrackable` concern in models you want to track

## Usage

### Accessing the Admin Panel

Navigate to `/admin` to access the admin dashboard. Only users with admin privileges can access this area.

### User Activity Feed

Regular users can access their personal activity feed at `/activity`. This shows:
- Recent actions and events
- Chronological timeline view
- Filtering by workspace, date range, and activity type
- Beautiful icons and color coding for different activity types

### Enhanced Audit Logs

Admins can access comprehensive audit logs with:
- Advanced filtering options (resource type, event type, workspace, date range)
- Full-text search capabilities
- CSV export functionality for reporting
- Detailed change tracking with before/after values

### User Activities Dashboard

Admins can monitor all user activities at `/admin/user_activities` with:
- Cross-user activity monitoring
- Advanced filtering and search
- Timeline view of all platform activities
- Export capabilities for compliance and reporting

### Impersonating Users

1. Go to the Users section in the admin panel
2. Click "Impersonate" next to any user
3. A banner will appear showing you're impersonating
4. Click "Stop Impersonating" to return to your admin session

### Managing Feature Flags

1. Visit the Feature Flags section
2. Toggle features on/off for different environments
3. Set up user-specific feature access

## Activity Tracking

To track activities for your models, include the `ActivityTrackable` concern:

```ruby
class YourModel < ApplicationRecord
  include ActivityTrackable
  
  # Override these methods to customize activity tracking
  private
  
  def activity_user
    # Return the user who performed the action
    current_user
  end
  
  def activity_workspace
    # Return the associated workspace
    self.workspace
  end
  
  def create_activity_description
    "Created #{self.class.name.humanize.downcase}: #{self.name}"
  end
end
```

You can also manually log activities:

```ruby
UserActivity.log_user_activity(
  user: current_user,
  action: 'subscription_created',
  description: 'Upgraded to Pro plan',
  resource: subscription,
  workspace: current_workspace,
  metadata: { plan: 'pro', amount: 29.99 }
)
```

## Security

- **Role-based access:** Only authorized admin users can access the panel
- **Session management:** Secure impersonation with automatic timeouts
- **Audit trail:** All admin actions are logged for accountability
- **Activity isolation:** Users can only see their own activities
- **CSRF protection:** All forms include CSRF tokens

## Testing

Run the admin module tests:

```bash
bin/synth test admin
```

## Customization

The admin panel is designed for extension. You can:
- Add new admin controllers by inheriting from `Admin::BaseController`
- Customize audit rules by updating the `Auditable` concern
- Add new feature flag categories in the Flipper dashboard
- Extend the impersonation system with additional safeguards
- Customize activity tracking by overriding methods in `ActivityTrackable`
- Add new activity types to `UserActivity::ACTIVITY_TYPES`

## Dependencies

This module adds the following gems:
- `flipper` - Feature flag management
- `flipper-ui` - Web interface for feature flags
- `paper_trail` - Model versioning and audit trails
- `pundit` - Authorization framework

All dependencies are automatically added during installation.