# Paranoid Mode Security

Paranoid Mode is an enhanced security configuration for the Rails SaaS Starter Template. When enabled, it provides enterprise-grade security features including secure headers, session management, two-factor authentication, and data encryption.

## Features

### 🔒 Secure Headers & CSP
- **Content Security Policy (CSP)**: Prevents XSS attacks and resource injection
- **HTTP Strict Transport Security (HSTS)**: Forces HTTPS connections
- **Security Headers**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- **Referrer Policy**: Controls referrer information leakage

### ⏰ Session Security
- **Automatic Session Expiry**: Sessions expire after configurable inactivity period
- **Secure Session Configuration**: httpOnly, secure, and sameSite cookie settings
- **Session Activity Tracking**: Real-time monitoring of user activity

### 🔐 Admin Two-Factor Authentication
- **TOTP Support**: Time-based one-time passwords compatible with Google Authenticator
- **Backup Codes**: Emergency access codes for account recovery
- **QR Code Generation**: Easy setup with authenticator apps
- **Enforced for Admins**: Automatic 2FA requirement for admin users

### 🛡️ Data Encryption
- **Sensitive Attribute Encryption**: First name, last name, and 2FA secrets encrypted at rest
- **AES-256-GCM Encryption**: Industry-standard encryption algorithm
- **Transparent Operation**: Automatic encryption/decryption in application layer

## Configuration

### Environment Variables

Create a `.env` file based on `.env.paranoid.example`:

```bash
# Enable Paranoid Mode
PARANOID_MODE=true

# Security Settings
PARANOID_FORCE_HTTPS=true
PARANOID_SESSION_TIMEOUT_MINUTES=30
PARANOID_ADMIN_2FA_REQUIRED=true
PARANOID_ENCRYPT_SENSITIVE_DATA=true
```

### Encryption Keys

Set up encryption keys in Rails credentials:

```bash
# Edit credentials
rails credentials:edit

# Add encryption key
encryption_key: your_64_character_hex_key_here
```

Generate a secure encryption key:
```ruby
SecureRandom.hex(32)
```

### Database Migrations

Run the paranoid mode migrations:

```bash
rails db:migrate
```

This adds the following fields to the users table:
- `encrypted_first_name` and `encrypted_first_name_iv`
- `encrypted_last_name` and `encrypted_last_name_iv`
- `encrypted_two_factor_secret` and `encrypted_two_factor_secret_iv`
- `backup_codes` (JSON array)

## Usage

### Basic Setup

1. **Add gems** (already included):
   ```ruby
   gem 'secure_headers', '~> 6.5'
   gem 'attr_encrypted', '~> 4.0'
   gem 'rotp', '~> 6.3'
   gem 'rqrcode', '~> 2.2'
   ```

2. **Include concerns in ApplicationController**:
   ```ruby
   class ApplicationController < ActionController::Base
     include ParanoidSessionManagement
     include ParanoidTwoFactorAuth if ParanoidMode.enabled?
   end
   ```

3. **Configure environment**:
   ```bash
   export PARANOID_MODE=true
   ```

### Two-Factor Authentication

#### For Users
```ruby
# Enable 2FA
user.enable_two_factor!

# Get QR code for setup
qr_uri = user.two_factor_qr_code_uri("Your App Name")

# Generate backup codes
backup_codes = user.generate_backup_codes!

# Verify TOTP token
totp = ROTP::TOTP.new(user.two_factor_secret)
valid = totp.verify(user_provided_token)

# Verify backup code
user.verify_backup_code("ABCD1234")
```

#### For Admin Enforcement
```ruby
# Check if admin 2FA is verified
if admin_2fa_verified?
  # Admin can access protected resources
else
  # Redirect to 2FA verification
end

# Verify admin 2FA token
if verify_admin_2fa_token(token)
  # Access granted
end
```

### Session Management

#### Controller Integration
```ruby
class ApplicationController < ActionController::Base
  include ParanoidSessionManagement
  
  private
  
  def redirect_to_login
    redirect_to login_path
  end
end
```

#### Session Timeout
```ruby
# Check remaining session time
remaining_seconds = paranoid_session_timeout_remaining

# Manual session expiry
expire_session_with_message("Custom expiry message")
```

### Content Security Policy

The default CSP configuration can be customized:

```ruby
# config/initializers/paranoid_mode.rb
ParanoidMode.configure do |config|
  config.content_security_policy = {
    default_src: ["'self'"],
    script_src: ["'self'", "https://trusted-cdn.com"],
    style_src: ["'self'", "'unsafe-inline'"],
    img_src: ["'self'", "data:", "https:"],
    font_src: ["'self'", "https://fonts.gstatic.com"],
    connect_src: ["'self'", "https://api.example.com"],
    object_src: ["'none'"],
    base_uri: ["'self'"],
    form_action: ["'self'"]
  }
end
```

## Development vs Production

### Development Mode
- HTTPS enforcement disabled by default
- Longer session timeouts (1 hour)
- Less strict CSP for development tools

### Production Mode
- HTTPS enforcement enabled
- Shorter session timeouts (30 minutes)
- Strict CSP and security headers
- HSTS with preload enabled

## Testing

Run the paranoid mode tests:

```bash
# All paranoid mode tests
rails test test/lib/paranoid_mode_test.rb
rails test test/models/user_paranoid_mode_test.rb
rails test test/integration/paranoid_session_management_test.rb

# With paranoid mode enabled
PARANOID_MODE_TEST=true rails test
```

## Monitoring

### Security Headers
Check that security headers are properly set:

```bash
curl -I https://your-app.com
```

Look for:
- `Strict-Transport-Security`
- `Content-Security-Policy`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`

### Session Activity
Monitor session expiry in logs:

```ruby
Rails.logger.info "Session expired for user #{user.id}" if session_expired?
```

### 2FA Usage
Track 2FA adoption:

```ruby
admin_users_with_2fa = User.where(admin: true).select(&:two_factor_enabled?)
```

## Security Considerations

1. **Encryption Keys**: Store encryption keys securely, never in version control
2. **Backup Codes**: Treat backup codes like passwords, store securely
3. **Session Storage**: Consider Redis for session storage in multi-server deployments
4. **HTTPS**: Always use HTTPS in production with valid certificates
5. **Regular Updates**: Keep security gems updated regularly

## Troubleshooting

### Missing Encryption Key
```
Error: Encryption key not configured
```
Solution: Add `encryption_key` to Rails credentials

### Session Expiry Issues
```
Session expired unexpectedly
```
Check: Session timeout configuration and server time sync

### 2FA Setup Problems
```
Invalid QR code
```
Verify: `two_factor_secret` is properly generated and stored

### CSP Violations
```
Content Security Policy directive violations
```
Solution: Review and adjust CSP configuration for your app's needs

## Contributing

When adding new features to paranoid mode:

1. Add configuration options to `ParanoidMode::Configuration`
2. Include tests for both enabled and disabled states
3. Document environment variables and usage
4. Consider backward compatibility
5. Update this README with new features

## Security Disclosure

If you discover security vulnerabilities in paranoid mode, please report them responsibly to the maintainers.