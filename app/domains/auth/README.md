# Auth Module

This module provides comprehensive authentication features including user registration, login, OAuth integration, and two-factor authentication.

## Features

- **Devise Integration**: Complete user authentication with registration, login, password reset
- **OAuth Providers**: Google and GitHub OAuth integration
- **Two-Factor Authentication**: TOTP-based 2FA with QR codes and backup codes
- **User Management**: Extended user profiles with avatars, timezones, and login tracking
- **Session Management**: Secure session handling with proper logout

## Installation

```bash
bin/synth add auth
```

This installs:
- Devise with User model
- OmniAuth providers (Google, GitHub)
- Two-factor authentication system
- Identity model for OAuth linkage
- Session and 2FA controllers

## Post-Installation

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Configure OAuth credentials:**
   ```bash
   rails credentials:edit
   ```
   Add:
   ```yaml
   google:
     client_id: your_google_client_id
     client_secret: your_google_client_secret
   github:
     client_id: your_github_client_id
     client_secret: your_github_client_secret
   ```

3. **Add routes:**
   ```ruby
   devise_for :users, controllers: { 
     sessions: 'sessions',
     omniauth_callbacks: 'sessions'
   }
   get '/auth/:provider/callback', to: 'sessions#omniauth'
   resource :two_factor, only: [:show, :create, :destroy] do
     patch :enable
     delete :disable
   end
   ```

4. **Include authentication concern:**
   ```ruby
   # app/models/user.rb
   class User < ApplicationRecord
     include UserAuthentication
     devise :database_authenticatable, :registerable, :recoverable, 
            :rememberable, :validatable, :confirmable, :lockable
   end
   ```

## Usage

### Basic Authentication
Users can register and login with email/password or OAuth providers.

### Two-Factor Authentication
```ruby
# Enable 2FA for a user
user.update!(two_factor_secret: ROTP::Base32.random)

# Verify 2FA code
user.verify_two_factor(params[:code])

# Generate QR code for setup
user.two_factor_qr_code
```

### OAuth Integration
Users can link multiple OAuth providers to their account via the Identity model.

## Security Features

- Email confirmation required
- Account lockout after failed attempts
- CSRF protection for OAuth
- Secure password requirements
- Backup codes for 2FA recovery

## Testing

```bash
bin/synth test auth
```

## Version

Current version: 1.0.0