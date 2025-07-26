# User Settings Module

Provides comprehensive user settings dashboard where users can manage their profile details, credentials, two-factor authentication, OAuth accounts, and preferences.

## Features

- **Profile Management**: Update name, avatar, and email address
- **Credentials Management**: Change password securely
- **Two-Factor Authentication**: Enable/disable 2FA and manage backup codes
- **OAuth Account Management**: Connect and disconnect Google, GitHub, and Slack accounts
- **User Preferences**: Set locale, timezone, and notification preferences
- **Strong Validations**: Comprehensive validation for all user inputs
- **Security**: Proper authorization and secure handling of sensitive data

## Installation

1. Install the user settings module:
   ```bash
   bin/synth add user_settings
   ```

2. Run the migrations:
   ```bash
   rails db:migrate
   ```

3. Add routes to your `config/routes.rb`:
   ```ruby
   resource :settings, only: [:show, :update], controller: 'user_settings' do
     member do
       patch :update_profile
       patch :update_password
       patch :update_preferences
     end
   end
   ```

## Dependencies

This module requires the following modules to be installed:
- `auth` - For user authentication and OAuth integration

## Usage

### Profile Management
Users can update their first name, last name, email, and avatar URL through the settings dashboard.

### Password Changes
Secure password updates with current password verification.

### Two-Factor Authentication
Users can enable/disable 2FA and view/regenerate backup codes. Integrates with the existing auth module's 2FA system.

### OAuth Management
View connected OAuth accounts (Google, GitHub, Slack) and connect/disconnect them.

### Preferences
Set user preferences including:
- Locale for internationalization
- Timezone for date/time display
- Notification preferences

## Security Features

- Current password required for password changes
- Email verification for email changes
- Proper authorization checks
- Secure handling of 2FA codes and backup codes
- CSRF protection for all forms

## Testing

```bash
bin/synth test user_settings
```

## Version

Current version: 1.0.0