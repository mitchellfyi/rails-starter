# frozen_string_literal: true

# Deploy module installer for the Rails SaaS Starter Template
# This module adds deployment configurations and environment management tools

say 'Installing Deploy module...'

# Copy deployment configuration files
copy_file 'fly.toml', 'fly.toml'
copy_file 'render.yaml', 'render.yaml'  
copy_file 'kamal.yml', 'kamal.yml'
copy_file 'Dockerfile', 'Dockerfile'
copy_file '.env.example', '.env.example'

# Copy build and deployment scripts
empty_directory 'bin'
copy_file 'bin/render-build.sh', 'bin/render-build.sh'
copy_file 'bin/docker-entrypoint', 'bin/docker-entrypoint'
chmod 'bin/render-build.sh', 0o755
chmod 'bin/docker-entrypoint', 0o755

# Copy deployment rake tasks
empty_directory 'lib/tasks'
copy_file 'lib/tasks/deploy.rake', 'lib/tasks/deploy.rake'

# Copy health check controller
empty_directory 'app/controllers'
copy_file 'app/controllers/health_controller.rb', 'app/controllers/health_controller.rb'

# Add health check route
route "get '/health', to: 'health#show'"

# Copy GitHub Actions workflow for deployment testing
empty_directory '.github/workflows'
copy_file '.github/workflows/deployment-test.yml', '.github/workflows/deployment-test.yml'

# Add necessary gems for deployment
gem 'redis', '~> 5.4'

# Add deployment-related initializers
initializer 'health_check.rb', <<~RUBY
  # Configure health check endpoints for deployment platforms
  Rails.application.configure do
    # Add custom health check logic here if needed
    # This file is loaded after the application is initialized
  end
RUBY

say '✅ Deploy module installed successfully!'
say ''
say 'Next steps:'
say '1. Copy .env.example to .env and fill in your configuration'
say '2. Customize deployment configs (fly.toml, render.yaml, kamal.yml) for your app'
say '3. Run: rails deploy:validate_env to check your configuration'
say '4. Run: rails deploy:bootstrap to set up a new environment'
say ''
say 'Deployment platforms supported:'
say '- Fly.io: Configure with fly.toml and deploy with `fly deploy`'
say '- Render: Configure with render.yaml and connect your GitHub repo'
say '- Kamal: Configure with kamal.yml and deploy with `kamal deploy`'