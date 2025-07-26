# frozen_string_literal: true

# Template script for generating a new Rails SaaS Starter application.
#
# Usage:
#   rails new myapp --dev -m https://example.com/template.rb
#
# This script will guide you through setting up the base stack for the
# Rails SaaS Starter Template.  It appends necessary gems to your
# Gemfile, runs generators for authentication, background jobs, and
# Tailwind/Hotwire, and scaffolds workspace/team models.  It also
# installs a command‑line interface (`bin/synth`) and a default AI
# module skeleton.  Feel free to customise this script to suit your
# project’s needs.

say "🪝 Setting up Rails SaaS Starter Template..."

# Add gems to the Gemfile
gem 'pg', '~> 1.5'
gem 'pgvector', '~> 0.5'
gem 'pgvector', '~> 0.3.2'
gem 'redis', '~> 5.4'
gem 'sidekiq', '~> 8.0'
gem 'devise', '~> 4.9'

gem 'omniauth', '~> 2.1'
gem 'stripe', '~> 15.3'
gem 'pundit', '~> 2.1'
gem 'turbo-rails', '~> 1.5'
gem 'stimulus-rails', '~> 1.2'
gem 'tailwindcss-rails', '~> 4.3'
gem 'jsonapi-serializer', '~> 3.2'

gem 'rswag', '~> 2.14'

gem_group :development, :test do
  gem 'dotenv-rails', '~> 3.1'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.3'
  gem 'rspec-rails', '~> 8.0'
end

after_bundle do
  # Install Hotwire and Tailwind
  rails_command 'turbo:install'
  rails_command 'stimulus:install'
  rails_command 'tailwindcss:install'

  # Set up authentication with Devise
  generate 'devise:install'
  generate 'devise', 'User'

  # Configure Sidekiq as the Active Job backend
  environment "config.active_job.queue_adapter = :sidekiq", env: %w[development production test]

  # Scaffold workspace/team models
  generate :model, 'Workspace', 'name:string', 'slug:string'
  generate :model, 'Membership', 'workspace:references', 'user:references', 'role:string'

  # Mount Sidekiq web UI behind authentication (requires admin? method on User)
  route "require 'sidekiq/web'\nauthenticate :user, lambda { |u| u.respond_to?(:admin?) && u.admin? } do\n  mount Sidekiq::Web => '/admin/sidekiq'\nend"

  # Create bin/synth CLI
  run 'mkdir -p bin'
  create_file 'bin/synth', <<~RUBY
    #!/usr/bin/env ruby
    # frozen_string_literal: true

    require 'thor'
    require_relative '../lib/synth/cli'

    Synth::CLI.start(ARGV)
  RUBY
  run 'chmod +x bin/synth'

  # Create CLI implementation
  run 'mkdir -p lib/synth'
  create_file 'lib/synth/cli.rb', <<~RUBY
    # frozen_string_literal: true

    require 'thor'

    module Synth
      class CLI < Thor
        desc 'list', 'List installed modules'
        def list
          modules_path = File.expand_path('../templates/synth', __dir__)
          puts 'Installed modules:'

          if Dir.exist?(modules_path)

            Dir.children(modules_path).each { |m| puts "  - #{m}" }
          else
            puts '  (none)'
          end
        end

        desc 'add MODULE', 'Add a module (e.g. billing, ai)'
        def add(module_name)
          puts "[stub] Add module: #{module_name}"
          # TODO: implement installer loading lib/templates/synth/<module>/install.rb
        end

        desc 'remove MODULE', 'Remove a module'
        def remove(module_name)
          puts "[stub] Remove module: #{module_name}"
        end
        

        desc 'upgrade', 'Upgrade installed modules'
        def upgrade
          puts '[stub] Upgrade modules'
        end

        desc 'test ai', 'Run AI tests'
        def test(_name = 'ai')
          puts '[stub] Run AI tests'
        end

        desc 'doctor', 'Validate setup and keys'
        def doctor
          puts '[stub] Run diagnostics'
        end


        desc 'scaffold agent NAME', 'Scaffold a new AI agent'
        def scaffold(name)
          puts "[stub] Scaffold agent: #{name}"
        end
      end
    end

  RUBY

  # Create deployment configuration files and environment setup
  create_file '.env.example', <<~ENV
# Rails SaaS Starter Template - Environment Configuration
# Copy this file to .env and fill in your actual values

# Rails Configuration
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_base_here_generate_with_rails_secret
RAILS_LOG_LEVEL=info

# Database Configuration (PostgreSQL with pgvector extension)
DATABASE_URL=postgresql://username:password@localhost:5432/myapp_development

# Redis Configuration (for Sidekiq and caching)
REDIS_URL=redis://localhost:6379/0

# Authentication & Session Configuration
DEVISE_SECRET_KEY=your_devise_secret_key_here

# OmniAuth Configuration
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret

# Email Configuration (SMTP)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password
FROM_EMAIL=noreply@your_domain.com

# Stripe Configuration
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key

# AI/LLM Provider Configuration
OPENAI_API_KEY=sk-your_openai_api_key_here
ANTHROPIC_API_KEY=sk-ant-your_anthropic_api_key

# Application Configuration
APP_HOST=localhost:3000
APP_NAME=Rails SaaS Starter

# Feature Flags
FEATURE_AI_ENABLED=true
FEATURE_BILLING_ENABLED=true
  ENV
  
  # Add health check route
  route "get '/health', to: 'health#show'"
  
  # Create health check controller
  create_file 'app/controllers/health_controller.rb', <<~RUBY
# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :authenticate_user!, if: :devise_controller?
  skip_before_action :verify_authenticity_token
  
  def show
    checks = {
      database: check_database,
      redis: check_redis
    }
    
    healthy = checks.all? { |_service, status| status[:healthy] }
    
    response_data = {
      status: healthy ? 'healthy' : 'unhealthy',
      timestamp: Time.current.iso8601,
      checks: checks
    }
    
    status_code = healthy ? :ok : :service_unavailable
    render json: response_data, status: status_code
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { healthy: true, message: 'Database connection successful' }
  rescue => e
    { healthy: false, message: "Database error: #{e.message}" }
  end

  def check_redis
    Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')).ping
    { healthy: true, message: 'Redis connection successful' }
  rescue => e
    { healthy: false, message: "Redis error: #{e.message}" }
  end
end
  RUBY
  
  # Create deployment rake tasks
  create_file 'lib/tasks/deploy.rake', <<~RUBY
# frozen_string_literal: true

namespace :deploy do
  desc 'Bootstrap a new environment'
  task bootstrap: :environment do
    puts '🚀 Bootstrapping new environment...'
    Rake::Task['db:create'].invoke
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:seed'].invoke
    puts '🎉 Environment bootstrap completed!'
  end

  desc 'Validate environment configuration'
  task validate_env: :environment do
    errors = []
    
    required_vars = %w[SECRET_KEY_BASE DATABASE_URL REDIS_URL]
    required_vars.each do |var|
      errors << "#{var} is not set" if ENV[var].blank?
    end
    
    if errors.any?
      puts "❌ Environment validation failed:"
      errors.each { |error| puts "   - #{error}" }
      exit 1
    else
      puts "✅ Environment configuration is valid"
    end
  end
end
  RUBY
  
  # Create deploy module for synth CLI
  run 'mkdir -p lib/templates/synth/deploy'
  create_file 'lib/templates/synth/deploy/install.rb', <<~RUBY
say 'Installing Deploy module...'
say '✅ Deploy module installed!'
say 'Run: rails deploy:validate_env to check configuration'
  RUBY
  create_file 'lib/templates/synth/deploy/README.md', <<~MD
# Deploy Module

Provides deployment configuration and environment management tools.
  MD
  
  # Create comprehensive deployment documentation
  create_file 'DEPLOYMENT.md', <<~MD
# Deployment Guide

This guide covers deploying your Rails SaaS Starter application to various platforms.

## Quick Start

1. **Configure environment**: Copy `.env.example` to `.env` and fill in your values
2. **Validate setup**: Run `rails deploy:validate_env`
3. **Choose platform**: Select from Fly.io, Render, or Kamal deployment
4. **Deploy**: Follow platform-specific instructions below

## Environment Configuration

### Required Variables

```bash
# Core Rails configuration
SECRET_KEY_BASE=your_secret_key_base
DATABASE_URL=postgresql://user:pass@host:5432/dbname
REDIS_URL=redis://host:6379/0

# Application settings
APP_HOST=your-domain.com
FROM_EMAIL=noreply@your-domain.com
```

For complete configuration options, see `.env.example`.

## Platform Deployment

### Fly.io
```bash
fly launch
fly secrets set SECRET_KEY_BASE=$(rails secret)
fly deploy
```

### Render
Connect your GitHub repository to Render and use Blueprint deployment.

### Kamal
```bash
kamal setup
kamal deploy
```

See the full deployment files in `lib/templates/` for complete configurations.
  MD
  
  # Create an example AI module skeleton
  run 'mkdir -p lib/templates/synth/ai'
  create_file 'lib/templates/synth/ai/install.rb', <<~RUBY
    # frozen_string_literal: true

    # Example installer for the AI module.  In a real implementation this
    # would create models, migrations, jobs, controllers, and tests for
    # prompt templates, LLM jobs, and MCP integration.
    say 'Installing AI module...'
    # TODO: implement prompt template models and LLM job system
  RUBY
  create_file 'lib/templates/synth/ai/README.md', <<~MD
    # AI Module

    Provides prompt templates, asynchronous LLM job processing, and a multi‑context provider (MCP).

    - **Prompt templates** store prompts with variables, tags, and versions.
    - **LLM jobs** run prompts asynchronously via Sidekiq, handling retries and logging inputs/outputs.
    - **MCP** fetches context from your database, external APIs, files, semantic memory, or code.

    Install this module via:

    ```sh
    bin/synth add ai
    ```

    It will add the necessary models, migrations, routes, controllers, and tests.
  MD
end

say "✅ Template setup complete.  Run `bin/setup` to finish configuring your application."
say ""
say "🚀 Deployment files have been created:"
say "   - .env.example (copy to .env and fill in your values)"
say "   - Health check endpoint at /health"
say "   - Deployment rake tasks (run 'rails deploy:validate_env')"
say ""
say "📁 Additional deployment configs available in lib/templates/:"
say "   - fly.toml (Fly.io deployment)"
say "   - render.yaml (Render deployment)"  
say "   - kamal.yml (Kamal deployment)"
say "   - Dockerfile (Docker builds)"
