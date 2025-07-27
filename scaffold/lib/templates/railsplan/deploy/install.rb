# frozen_string_literal: true

# Deploy module installation script
# This script sets up deployment configurations for Fly.io, Render, and Kamal

say_status :railsplan_deploy, "Installing deploy module..."

# Create domain-specific directories
run 'mkdir -p app/domains/deploy/app/controllers'

# Template directory path
template_dir = File.dirname(__FILE__)

# Copy Fly.io configuration
template File.join(template_dir, 'fly.toml.tt'), 'fly.toml'

# Copy Render configuration  
template File.join(template_dir, 'render.yaml.tt'), 'render.yaml'

# Copy Kamal configuration
template File.join(template_dir, 'config/deploy.yml.tt'), 'config/deploy.yml'
copy_file File.join(template_dir, 'config/postgres/init.sql'), 'config/postgres/init.sql'

# Copy container files
copy_file File.join(template_dir, 'Dockerfile'), 'Dockerfile'
copy_file File.join(template_dir, '.dockerignore'), '.dockerignore'

# Copy environment template
copy_file File.join(template_dir, '.env.production.example'), '.env.production.example'

# Copy GitHub Actions workflows
copy_file File.join(template_dir, '.github/workflows/fly-deploy.yml'), '.github/workflows/fly-deploy.yml'
copy_file File.join(template_dir, '.github/workflows/kamal-deploy.yml'), '.github/workflows/kamal-deploy.yml'

# Create health check endpoint
route <<~RUBY
  scope module: :deploy do
    get '/health', to: 'health#show'
  end
RUBY

# Create health controller
create_file 'app/domains/deploy/app/controllers/health_controller.rb', <<~RUBY
  # frozen_string_literal: true

  class HealthController < ApplicationController
    def show
      render json: { 
        status: 'ok', 
        timestamp: Time.current,
        version: Rails.application.config.version || '1.0.0'
      }
    end
  end
RUBY

# Add deployment-related gems
gem 'kamal', group: :development

say_status :railsplan_deploy, "✅ Deploy module installed!"
say ""
say "Next steps:"
say "1. Review and customize deployment configurations:"
say "   - fly.toml (Fly.io)"
say "   - render.yaml (Render)"
say "   - config/deploy.yml (Kamal)"
say ""
say "2. Set up your environment variables:"
say "   - Copy .env.production.example to .env.production"
say "   - Fill in your secrets and configuration"
say ""
say "3. Deploy to your chosen platform:"
say "   - Fly.io: flyctl launch"
say "   - Render: Connect your GitHub repo"
say "   - Kamal: kamal setup"
say ""
say "See the deploy module README for detailed instructions."