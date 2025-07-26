# frozen_string_literal: true

# Template script for generating a new Rails SaaS Starter application.
#
# Usage:
#   rails new myapp --dev -m https://example.com/template.rb
#
# This script will guide you through setting up the base stack for the
# Rails SaaS
Starter Template.  It appends necessary gems to your
# Gemfile, runs generators for authentication, background jobs, and
# Tailwind/Hotwire, and scaffolds workspace/team models.  It also
# installs a command
line interface (`bin/synth`) and a default AI
# module skeleton.  Feel free to customise this script to suit your
# project’s needs.

# Helper to load modular setup files
def load_template_file(file_path)
  load File.expand_path(file_path, __dir__)
end

say "
 Setting up Rails SaaS Starter Template..."

load_template_file 'setup/gems.rb'

after_bundle do
  # Add helper method for checking gem existence
  def gem_exists?(gem_name)
    File.read('Gemfile').include?(gem_name)
  end

  load_template_file 'setup/initial_rails_setup.rb'

  # Install core modules using bin/synth
  say "
 Installing core modules..."
  run 'bin/synth add auth'
  run 'bin/synth add workspace'
  run 'bin/synth add api'
  run 'bin/synth add deploy'
  run 'bin/synth add ai'
  run 'bin/synth add billing'
  run 'bin/synth add cms'
  run 'bin/synth add i18n'
  run 'bin/synth add admin'
  run 'bin/synth add docs'
  run 'bin/synth add testing'

  load_template_file 'setup/synth_cli_setup.rb'
  load_template_file 'setup/environment_config.rb'
  load_template_file 'setup/api_serializers.rb'
  load_template_file 'setup/base_routes.rb'

  # Run database setup
  say "
  Setting up database..."
  rails_command 'db:create'
  rails_command 'db:migrate'

  # Create bin/setup script
  create_file 'bin/setup', <<~BASH
    #!/usr/bin/env bash
    set -euo pipefail
    IFS=$'\n\t'
    set -vx

    bundle install

    # Install or update JavaScript dependencies
    yarn install --frozen-lockfile || npm install

    # Copy environment variables if .env doesn't exist
    if [ ! -f .env ]; then
      cp .env.example .env
      echo "Created .env file - please update with your actual values"
    fi

    # Set up database
    bin/rails db:prepare

    # Remove old logs and tempfiles
    bin/rails log:clear tmp:clear

    # Restart application server
    bin/rails restart
  BASH
  run 'chmod +x bin/setup'

  # Create bin/dev script for development
  create_file 'bin/dev', <<~BASH
    #!/usr/bin/env bash

    if ! command -v foreman &> /dev/null; then
      echo "Installing foreman..."
      gem install foreman
    fi

    exec foreman start -f Procfile.dev "$@"
  BASH
  run 'chmod +x bin/dev'

  # Create Procfile.dev for development
  create_file 'Procfile.dev', <<~PROCFILE
    web: bin/rails server -p 3000
    css: bin/rails tailwindcss:watch
    sidekiq: bundle exec sidekiq
  PROCFILE

  # Create README with setup instructions
  create_file 'README_SETUP.md', <<~MD
    # Rails SaaS Starter - Setup Complete! 

    Your Rails SaaS application has been successfully generated with the following features:

    ## 
 Features Included

    ### Authentication & Authorization
    - **Devise** for user authentication with email/password
    - **OmniAuth** providers (Google, GitHub, Slack)
    - User confirmations, account lockout, and 2FA ready
    - **Pundit** for authorization

    ### Database & Background Jobs
    - **PostgreSQL** with pgvector extension for vector embeddings
    - **Sidekiq** + **Redis** for background job processing
    - Database migrations for users, workspaces, memberships, and invitations

    ### Frontend
    - **TailwindCSS** for styling
    - **Hotwire** (Turbo + Stimulus) for modern frontend interactions
    - Responsive design ready

    ### API & Team Management
    - **JSON:API** compliant REST API
    - Workspace/team models with role-based permissions
    - Invitation system for team collaboration
    - Slug-based routing with FriendlyId

    ## 
 Getting Started

    1. **Install dependencies:**
       ```bash
       bin/setup
       ```

    2. **Configure environment variables:**
       ```bash
       cp .env.example .env
       # Edit .env with your actual values
       ```

    3. **Start the development server:**
       ```bash
       bin/dev
       ```

    4. **Visit your application:**
       - Web interface: http://localhost:3000
       - Sidekiq dashboard: http://localhost:3000/admin/sidekiq (admin users only)

    ## 
 Configuration

    ### Database
    Make sure PostgreSQL is running and the pgvector extension is available:
    ```sql
    CREATE EXTENSION IF NOT EXISTS vector;
    ```

    ### Redis
    Ensure Redis is running for Sidekiq background jobs:
    ```bash
    redis-server
    ```

    ### OmniAuth Providers
    Configure your OAuth applications and update `.env`:
    - Google: https://console.developers.google.com/
    - GitHub: https://github.com/settings/developers
    - Slack: https://api.slack.com/apps

    ## 
 Running Tests

    ```bash
    # Run all tests
    bin/rails test

    # Or with RSpec (if installed)
    bundle exec rspec
    ```

    ## 
 API Usage

    The application provides a JSON:API compliant REST API at `/api/v1/`:

    ```bash
    # Get user's workspaces
    curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3000/api/v1/workspaces

    # Create a new workspace
    curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer YOUR_TOKEN" \
         -d '{"workspace":{"name":"My Workspace","description":"A new workspace"}}' \
         http://localhost:3000/api/v1/workspaces
    ```

    ## 
 Next Steps

    1. Customize the design and branding
    2. Add your business-specific models and features
    3. Configure deployment (Fly.io, Render, Heroku, etc.)
    4. Set up monitoring and error tracking
    5. Add more OAuth providers as needed

    ## 
 Team Management

    - **Owners** can manage all aspects of a workspace
    - **Admins** can invite/remove members and manage settings
    - **Members** have standard access to workspace features
    - Use the invitation system to add team members via email

    Enjoy building your SaaS application! 
  MD

  say ""
  say "
 Rails SaaS Starter Template setup complete!"
  say ""
  say "
 Next steps:"
  say "   1. cd into your application directory"
  say "   2. Run 'bin/setup' to complete configuration"  
  say "   3. Update .env with your actual values"
  say "   4. Run 'bin/dev' to start the development server"
  say ""
  say "
 Check README_SETUP.md for detailed instructions"
  say ""
end