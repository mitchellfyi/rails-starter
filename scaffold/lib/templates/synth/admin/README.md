# Admin Panel Module

This module adds a comprehensive admin panel to your Rails SaaS application with advanced administrative features for user management, system monitoring, and feature control.

## Features

### 🎭 User Impersonation
- **Safe impersonation:** Admins can impersonate users for support and testing
- **Session management:** Clear sign-out and revert-to-admin safeguards
- **Audit trail:** All impersonation activities are logged

### 📊 Audit Logs
- **Comprehensive tracking:** Records changes to critical resources (users, billing, content, prompts)
- **Searchable interface:** Filter and search logs by actor, resource, timestamp
- **Detailed metadata:** Captures before/after states, IP addresses, user agents

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
- Create audit log models and migrations
- Set up authentication and authorization
- Configure Sidekiq UI mounting
- Install Flipper for feature flag management
- Add comprehensive test coverage

## Configuration

After installation, configure admin access by:

1. **Setting admin roles:** Update your User model to include admin privileges
2. **Configuring feature flags:** Set up initial feature flags in the Flipper dashboard
3. **Customizing audit rules:** Define which models and actions should be audited

## Usage

### Accessing the Admin Panel

Navigate to `/admin` to access the admin dashboard. Only users with admin privileges can access this area.

### Impersonating Users

1. Go to the Users section in the admin panel
2. Click "Impersonate" next to any user
3. A banner will appear showing you're impersonating
4. Click "Stop Impersonating" to return to your admin session

### Managing Feature Flags

1. Visit the Feature Flags section
2. Toggle features on/off for different environments
3. Set up user-specific feature access

### Viewing Audit Logs

1. Access the Audit Logs section
2. Use filters to search by user, resource type, or date range
3. View detailed information about each logged action

## Security

- **Role-based access:** Only authorized admin users can access the panel
- **Session management:** Secure impersonation with automatic timeouts
- **Audit trail:** All admin actions are logged for accountability
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

## Dependencies

This module adds the following gems:
- `flipper` - Feature flag management
- `flipper-ui` - Web interface for feature flags
- `paper_trail` - Model versioning and audit trails
- `pundit` - Authorization framework

All dependencies are automatically added during installation.