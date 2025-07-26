# frozen_string_literal: true

# Deploy module installer
say 'Installing Deploy module...'

# Create deployment directory structure
empty_directory 'config/deploy'
empty_directory '.github/workflows'

# Create Fly.io configuration
create_file 'fly.toml', <<~TOML
  app = "my-rails-app"
  primary_region = "iad"

  [build]

  [http_service]
    internal_port = 3000
    force_https = true
    auto_stop_machines = "suspend"
    auto_start_machines = true
    min_machines_running = 0
    processes = ["app"]

  [[vm]]
    memory = "1gb"
    cpu_kind = "shared"
    cpus = 1

  [env]
    PORT = "3000"
    RAILS_ENV = "production"
TOML

# Create GitHub Actions workflow
create_file '.github/workflows/deploy.yml', <<~YAML
  name: Deploy to Production
  on:
    push:
      branches: [main]
  
  jobs:
    deploy:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Setup Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true
        - name: Run tests
          run: bundle exec rspec
        - name: Deploy to Fly.io
          uses: superfly/flyctl-actions@v1
          with:
            args: "deploy"
          env:
            FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
YAML

# Create production environment template
create_file '.env.production.example', <<~ENV
  # Production environment variables
  RAILS_MASTER_KEY=
  DATABASE_URL=
  REDIS_URL=
  
  # AI Providers
  OPENAI_API_KEY=
  ANTHROPIC_API_KEY=
  
  # Stripe
  STRIPE_PUBLISHABLE_KEY=
  STRIPE_SECRET_KEY=
  STRIPE_WEBHOOK_SECRET=
  
  # Email
  SMTP_HOST=
  SMTP_USERNAME=
  SMTP_PASSWORD=
ENV

say 'Deploy module installed! Configure fly.toml and environment variables for deployment'