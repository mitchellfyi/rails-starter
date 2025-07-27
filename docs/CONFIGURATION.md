# Configuration Guide

This guide covers all configuration options for the Rails SaaS Starter Template and its modules.

## Environment Setup

### Required Environment Variables

Create a `.env` file in your application root:

```bash
# Database
DATABASE_URL=postgresql://username:password@localhost:5432/myapp_development
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=your_password
DATABASE_HOST=localhost

# Redis
REDIS_URL=redis://localhost:6379/0

# Rails
SECRET_KEY_BASE=your_64_character_secret_key
RAILS_ENV=development

# Application
APP_HOST=localhost:3000
APP_PROTOCOL=http

# Mailer
MAILER_FROM_EMAIL=noreply@yourapp.com
MAILER_FROM_NAME="Your App"

# SMTP (for production)
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
```

### Development Environment

```bash
# .env.development
RAILS_LOG_LEVEL=debug
WEB_CONCURRENCY=1
RAILS_MAX_THREADS=5

# Development tools
RACK_MINI_PROFILER=true
```

### Production Environment

```bash
# .env.production
RAILS_ENV=production
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Performance
WEB_CONCURRENCY=4
RAILS_MAX_THREADS=10
RAILS_MIN_THREADS=5

# Security
FORCE_SSL=true
SECURE_HEADERS=true
```

## Database Configuration

### PostgreSQL Setup

```yaml
# config/database.yml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV.fetch("DATABASE_USERNAME", "postgres") %>
  password: <%= ENV.fetch("DATABASE_PASSWORD", "") %>
  host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>

development:
  <<: *default
  database: myapp_development

test:
  <<: *default
  database: myapp_test

production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
```

### pgvector Extension

Ensure pgvector is installed and enabled:

```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Verify installation
SELECT * FROM pg_extension WHERE extname = 'vector';
```

## Redis Configuration

### Basic Setup

```ruby
# config/initializers/redis.rb
require 'redis'

Redis.current = Redis.new(
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  timeout: 5,
  reconnect_attempts: 1
)

# For Sidekiq
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
```

### Production Redis

```bash
# Production Redis with connection pooling
REDIS_URL=redis://redis.example.com:6379/0
REDIS_POOL_SIZE=25
REDIS_TIMEOUT=5
```

## Authentication Configuration

### Devise Setup

```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  # Secret key for JWT tokens
  config.secret_key = Rails.application.credentials.secret_key_base
  
  # Email sender
  config.mailer_sender = ENV.fetch('MAILER_FROM_EMAIL', 'noreply@example.com')
  
  # Password requirements
  config.password_length = 8..128
  config.password_complexity = {
    digit: 1,
    lower: 1,
    upper: 1,
    symbol: 1
  }
  
  # Session timeout
  config.timeout_in = 30.minutes
  
  # Account lockout
  config.lock_strategy = :failed_attempts
  config.maximum_attempts = 10
  config.unlock_in = 1.hour
  
  # Confirmation
  config.confirm_within = 3.days
  config.reconfirmable = true
  
  # Two-factor authentication
  config.otp_secret_encryption_key = Rails.application.credentials.otp_secret_key
end
```

### OmniAuth Providers

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  # Google OAuth
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id),
    Rails.application.credentials.dig(:google, :client_secret),
    scope: 'email,profile'
  
  # GitHub OAuth
  provider :github,
    Rails.application.credentials.dig(:github, :client_id),
    Rails.application.credentials.dig(:github, :client_secret),
    scope: 'user:email'
  
  # Slack OAuth
  provider :slack,
    Rails.application.credentials.dig(:slack, :client_id),
    Rails.application.credentials.dig(:slack, :client_secret),
    scope: 'users:read,users:read.email'
end
```

### Credentials Management

```bash
# Edit credentials
bin/rails credentials:edit

# Add to config/credentials.yml.enc
google:
  client_id: your_google_client_id
  client_secret: your_google_client_secret

github:
  client_id: your_github_client_id
  client_secret: your_github_client_secret

slack:
  client_id: your_slack_client_id
  client_secret: your_slack_client_secret

# OTP secret for 2FA
otp_secret_key: your_32_character_secret
```

## Module Configurations

### AI Module

```ruby
# config/initializers/ai.rb
Rails.application.config.ai = ActiveSupport::OrderedOptions.new

# Default LLM settings
Rails.application.config.ai.default_model = ENV.fetch('AI_DEFAULT_MODEL', 'gpt-4')
Rails.application.config.ai.timeout = ENV.fetch('AI_TIMEOUT', 30).to_i
Rails.application.config.ai.max_tokens = ENV.fetch('AI_MAX_TOKENS', 4000).to_i

# Provider configurations
Rails.application.config.ai.providers = {
  openai: {
    api_key: Rails.application.credentials.dig(:openai, :api_key),
    organization: Rails.application.credentials.dig(:openai, :organization),
    base_url: ENV.fetch('OPENAI_BASE_URL', 'https://api.openai.com'),
    timeout: 30
  },
  anthropic: {
    api_key: Rails.application.credentials.dig(:anthropic, :api_key),
    base_url: ENV.fetch('ANTHROPIC_BASE_URL', 'https://api.anthropic.com'),
    timeout: 30
  }
}

# MCP (Multi-Context Provider) settings
Rails.application.config.ai.mcp = ActiveSupport::OrderedOptions.new
Rails.application.config.ai.mcp.enabled = ENV.fetch('MCP_ENABLED', 'true') == 'true'
Rails.application.config.ai.mcp.cache_ttl = ENV.fetch('MCP_CACHE_TTL', 300).to_i
Rails.application.config.ai.mcp.max_context_size = ENV.fetch('MCP_MAX_CONTEXT_SIZE', 50000).to_i
```

### Billing Module

```ruby
# config/initializers/billing.rb
require 'stripe'

Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)
Stripe.api_version = '2023-10-16'

Rails.application.config.billing = ActiveSupport::OrderedOptions.new

# Stripe configuration
Rails.application.config.billing.stripe = ActiveSupport::OrderedOptions.new
Rails.application.config.billing.stripe.publishable_key = Rails.application.credentials.dig(:stripe, :publishable_key)
Rails.application.config.billing.stripe.webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

# Billing settings
Rails.application.config.billing.trial_period_days = ENV.fetch('TRIAL_PERIOD_DAYS', 14).to_i
Rails.application.config.billing.grace_period_days = ENV.fetch('GRACE_PERIOD_DAYS', 3).to_i
Rails.application.config.billing.invoice_reminder_days = ENV.fetch('INVOICE_REMINDER_DAYS', 3).to_i

# Tax settings
Rails.application.config.billing.tax_rates = {
  'US' => ENV.fetch('STRIPE_TAX_RATE_US', 'txr_1234567890'),
  'EU' => ENV.fetch('STRIPE_TAX_RATE_EU', 'txr_0987654321')
}
```

### CMS Module

```ruby
# config/initializers/cms.rb
Rails.application.config.cms = ActiveSupport::OrderedOptions.new

# Content settings
Rails.application.config.cms.default_locale = ENV.fetch('CMS_DEFAULT_LOCALE', 'en')
Rails.application.config.cms.supported_locales = ENV.fetch('CMS_SUPPORTED_LOCALES', 'en,es,fr').split(',')

# SEO settings
Rails.application.config.cms.default_meta_title = ENV.fetch('CMS_DEFAULT_META_TITLE', 'Your App')
Rails.application.config.cms.default_meta_description = ENV.fetch('CMS_DEFAULT_META_DESCRIPTION', 'Your app description')
Rails.application.config.cms.meta_title_suffix = ENV.fetch('CMS_META_TITLE_SUFFIX', ' | Your App')

# File uploads
Rails.application.config.cms.max_upload_size = ENV.fetch('CMS_MAX_UPLOAD_SIZE', 10).to_i.megabytes
Rails.application.config.cms.allowed_file_types = ENV.fetch('CMS_ALLOWED_FILE_TYPES', 'jpg,jpeg,png,gif,pdf,doc,docx').split(',')

# Rich text editor
Rails.application.config.cms.editor = ENV.fetch('CMS_EDITOR', 'trix') # trix, quill, tinymce
```

## Background Jobs

### Sidekiq Configuration

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { 
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    size: ENV.fetch('REDIS_POOL_SIZE', 25).to_i
  }
  
  # Concurrency
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 5).to_i
  
  # Queues with priorities
  config.queues = %w[critical high default low]
end

Sidekiq.configure_client do |config|
  config.redis = { 
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    size: ENV.fetch('REDIS_POOL_SIZE', 5).to_i
  }
end

# Job retry configuration
Sidekiq.default_job_options = {
  retry: 3,
  backtrace: true,
  queue: 'default'
}
```

### Active Job Configuration

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq

# Queue names mapping
config.active_job.queue_name_prefix = ENV.fetch('ACTIVE_JOB_QUEUE_PREFIX', 'myapp')
config.active_job.queue_name_delimiter = '_'

# Default queue
config.active_job.default_queue_name = 'default'
```

## Security Configuration

### Content Security Policy

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline
    policy.style_src   :self, :https, :unsafe_inline
    
    # Allow Stripe
    policy.frame_src 'https://js.stripe.com', 'https://hooks.stripe.com'
    policy.connect_src :self, :https, 'https://api.stripe.com'
    
    # Development mode
    if Rails.env.development?
      policy.script_src :self, :https, :unsafe_eval, :unsafe_inline
      policy.connect_src :self, :https, 'http://localhost:3035', 'ws://localhost:3035'
    end
  end
  
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
```

### Secure Headers

```ruby
# config/initializers/secure_headers.rb
SecureHeaders::Configuration.default do |config|
  config.hsts = "max-age=#{1.year.to_i}; includeSubDomains"
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = %w[origin-when-cross-origin strict-origin-when-cross-origin]
  config.clear_site_data = %w[cache cookies storage executionContexts]
end
```

### CORS Configuration

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('CORS_ORIGINS', 'localhost:3000').split(',')
    
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

## Monitoring & Logging

### Application Monitoring

```ruby
# config/initializers/monitoring.rb
if Rails.env.production?
  # Add your monitoring service configuration
  # Example: New Relic, Datadog, etc.
end

# Custom metrics
Rails.application.config.metrics = ActiveSupport::OrderedOptions.new
Rails.application.config.metrics.enabled = ENV.fetch('METRICS_ENABLED', 'true') == 'true'
Rails.application.config.metrics.statsd_host = ENV.fetch('STATSD_HOST', 'localhost')
Rails.application.config.metrics.statsd_port = ENV.fetch('STATSD_PORT', 8125).to_i
```

### Logging Configuration

```ruby
# config/environments/production.rb
config.logger = ActiveSupport::Logger.new(STDOUT)
config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info').to_sym
config.log_tags = [:request_id, :remote_ip]

# Structured logging
config.colorize_logging = false
config.log_formatter = proc do |severity, datetime, progname, msg|
  {
    timestamp: datetime.iso8601,
    level: severity,
    message: msg,
    program: progname
  }.to_json + "\n"
end
```

## Performance Configuration

### Asset Pipeline

```ruby
# config/environments/production.rb
config.assets.compile = false
config.assets.digest = true
config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

# CDN configuration
config.asset_host = ENV['ASSET_HOST'] if ENV['ASSET_HOST'].present?

# Gzip compression
config.middleware.use Rack::Deflater
```

### Database Optimization

```ruby
# config/database.yml production settings
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 25 } %>
  timeout: 5000
  checkout_timeout: 5
  reaping_frequency: 10
  
  # Connection pooling for high-traffic apps
  variables:
    statement_timeout: 30s
    lock_timeout: 10s
    idle_in_transaction_session_timeout: 60s
```

### Caching

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_URL'],
  pool_size: ENV.fetch('RAILS_MAX_THREADS', 5).to_i,
  pool_timeout: 5,
  namespace: ENV.fetch('CACHE_NAMESPACE', 'myapp'),
  expires_in: 1.hour
}

# Page caching
config.action_controller.perform_caching = true
config.action_controller.enable_fragment_cache_logging = true
```

## Email Configuration

### Development (Letter Opener)

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

### Production (SMTP)

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_url_options = { 
  host: ENV['APP_HOST'], 
  protocol: ENV.fetch('APP_PROTOCOL', 'https') 
}

config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV.fetch('SMTP_PORT', 587).to_i,
  domain: ENV['APP_HOST'],
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

## File Storage

### Development (Local)

```ruby
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
  
# config/environments/development.rb
config.active_storage.variant_processor = :mini_magick
```

### Production (S3)

```ruby
# config/storage.yml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: <%= ENV.fetch('AWS_REGION', 'us-east-1') %>
  bucket: <%= ENV.fetch('AWS_S3_BUCKET', 'myapp-production') %>

# config/environments/production.rb
config.active_storage.service = :amazon
```

## Configuration Validation

Add validation to ensure required configuration is present:

```ruby
# config/initializers/configuration_validation.rb
Rails.application.configure do
  config.after_initialize do
    required_env_vars = %w[
      DATABASE_URL
      REDIS_URL
      SECRET_KEY_BASE
    ]
    
    missing_vars = required_env_vars.select { |var| ENV[var].blank? }
    
    if missing_vars.any?
      raise "Missing required environment variables: #{missing_vars.join(', ')}"
    end
    
    # Validate module configurations
    if defined?(Rails.application.config.ai)
      if Rails.application.config.ai.providers[:openai][:api_key].blank?
        Rails.logger.warn "OpenAI API key not configured. AI features will be limited."
      end
    end
  end
end
```

For deployment-specific configuration, see the deployment guides in the `docs/` directory.