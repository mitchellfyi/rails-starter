# Admin Panel - Rails SaaS Starter Template

This implementation provides core admin panel functionality for the Rails SaaS Starter Template, including feature flags, audit logging, and administrative controls.

## Features Implemented

### ✅ Feature Flags UI
- **Global feature flags** - Enable/disable features across the entire application
- **Per-workspace control** - Override global settings for specific workspaces
- **Feature flag management** - Create, edit, and toggle flags via web interface
- **Audit trail** - All feature flag changes are logged

### ✅ Audit Logging System
- **Admin impersonation logs** - Track when admins impersonate users
- **User login tracking** - Automatic logging of user authentication events
- **AI output reviews** - Log when users rate or review AI-generated content
- **System activity** - Track feature flag changes, admin actions, and more
- **Comprehensive filtering** - Search and filter by user, action, date, resource type

### ✅ Admin Panel Interface
- **Dashboard** - Overview of users, feature flags, and recent activity
- **Audit logs at `/admin/audit`** - Searchable audit trail interface
- **Feature flag management** - Full CRUD interface for feature flags
- **Clean, responsive UI** - Built with embedded CSS for no external dependencies

## File Structure

```
app/
├── controllers/admin/
│   ├── base_controller.rb          # Authentication & authorization base
│   ├── dashboard_controller.rb     # Admin dashboard
│   ├── audit_controller.rb         # Audit logs interface (/admin/audit)
│   └── feature_flags_controller.rb # Feature flag management
├── models/
│   ├── audit_log.rb               # Audit logging model
│   ├── feature_flag.rb            # Feature flag model  
│   ├── workspace_feature_flag.rb  # Per-workspace overrides
│   └── concerns/
│       └── admin_user_extensions.rb # User admin capabilities
├── views/
│   ├── layouts/admin.html.erb     # Admin panel layout
│   ├── admin/dashboard/           # Dashboard views
│   ├── admin/audit/               # Audit log views
│   └── admin/feature_flags/       # Feature flag views
└── helpers/
    └── feature_flag_helper.rb     # Helper methods for checking flags

config/
├── routes/admin.rb                # Admin panel routes
└── initializers/
    └── admin_audit_logging.rb     # Automatic login tracking

db/
├── migrate/
│   ├── 001_create_audit_logs.rb
│   ├── 002_create_feature_flags.rb
│   ├── 003_create_workspace_feature_flags.rb
│   └── 004_add_admin_to_users.rb
└── seeds/admin.rb                 # Default feature flags and sample data
```

## Usage

### Admin Access
1. Set a user as admin: `user.update!(admin: true)`
2. Access the admin panel at `/admin`
3. View audit logs at `/admin/audit`

### Feature Flags
```ruby
# In controllers/views - check if feature is enabled
if feature_enabled?(:new_ui)
  # Show new interface
end

# Check for specific workspace
if feature_enabled?(:beta_features, current_workspace)
  # Show beta features for this workspace
end
```

### Audit Logging
```ruby
# Manual audit logging
AuditLog.create_log(
  user: current_user,
  action: 'custom_action',
  description: 'User performed custom action',
  metadata: { additional: 'data' }
)

# Specific logging methods
AuditLog.log_login(user, ip_address: request.remote_ip)
AuditLog.log_impersonation(admin, target_user, 'start')
AuditLog.log_ai_review(user, ai_output, rating)
```

## Integration with Template

This admin functionality is designed to work with the Rails SaaS Starter Template's modular architecture:

- **Auth integration** - Works with Devise authentication when available
- **Workspace support** - Integrates with workspace module for per-workspace flags
- **AI module integration** - Provides audit logging for AI output reviews
- **No external dependencies** - Uses embedded CSS and standard Rails patterns

## Database Setup

Run the migrations to set up the required tables:

```bash
rails db:migrate
rails db:seed:admin  # Optional: creates sample feature flags
```

## Security

- Admin routes require user authentication and admin privileges
- All admin actions are logged in audit trails
- IP addresses and user agents are tracked for security
- Feature flag changes are audited with before/after states

## Extending

To add new audit log types:
1. Add the action to `AuditLog::VALID_ACTIONS` if needed
2. Create helper methods like `AuditLog.log_custom_action`
3. Call from your controllers where the action occurs

To add new feature flag types:
1. Create flags via the admin interface or seeds
2. Use `feature_enabled?(:flag_name)` in your code
3. Feature flags automatically support workspace overrides