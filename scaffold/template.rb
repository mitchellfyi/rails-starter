# frozen_string_literal: true

# Template script for generating a new Rails SaaS Starter application.
#
# Usage:
#   rails new myapp --dev -m https://example.com/template.rb
#
# This template uses Rails edge (main branch) by default for the latest features.
# To use Rails 8 stable instead, edit the Gemfile and comment out the edge line.
#
# Requirements:
#   - Ruby 3.4.2 (recommended for optimal compatibility)
#   - Rails edge (main branch) or Rails 8.0+
#
# This script will guide you through setting up the base stack for the
# Rails SaaS Starter Template. It appends necessary gems to your
# Gemfile, runs generators for authentication, background jobs, and
# Tailwind/Hotwire, and scaffolds workspace/team models. It also
# installs a command line interface (`bin/railsplan`) and a default AI
# module skeleton. Feel free to customise this script to suit your
# project's needs.

# Helper to load modular setup files
def load_template_file(file_path)
  load File.expand_path(file_path, __dir__)
end

say "🔧 Setting up Rails SaaS Starter Template..."

# Show Ruby version information
say_status :ruby, "Ruby #{RUBY_VERSION} detected (recommended: 3.4.2)"

# Configure Rails version (edge vs stable)
load_template_file 'setup/rails_version.rb'
configure_rails_version

load_template_file 'setup/gems.rb'

after_bundle do
  # Add helper method for checking gem existence
  def gem_exists?(gem_name)
    File.read('Gemfile').include?(gem_name)
  end

  load_template_file 'setup/initial_rails_setup.rb'
  load_template_file 'setup/railsplan_cli_setup.rb'

  # Install core modules using bin/railsplan
  say "🔧 Installing core modules..."
  run 'bin/railsplan add auth'
  run 'bin/railsplan add workspace'
  run 'bin/railsplan add onboarding'
  run 'bin/railsplan add api'
  run 'bin/railsplan add deploy'
  run 'bin/railsplan add ai'
  run 'bin/railsplan add billing'
  run 'bin/railsplan add cms'
  run 'bin/railsplan add i18n'
  run 'bin/railsplan add admin'
  run 'bin/railsplan add docs'
  run 'bin/railsplan add testing'
  run 'bin/railsplan add theme'

  load_template_file 'setup/environment_config.rb'
  load_template_file 'setup/api_serializers.rb'
  load_template_file 'setup/base_routes.rb'

  # Run database setup
  say "🗄️  Setting up database..."
  rails_command 'db:create'
  rails_command 'db:migrate'

  # Create bin/setup script
  create_file 'bin/setup', <<~BASH
    #!/usr/bin/env bash
    set -euo pipefail
    IFS=$'\n\t'
    set -vx

    bundle install

    # Install or update JavaScript dependencies if needed
    if [ -f "yarn.lock" ]; then
      yarn install --frozen-lockfile
    elif [ -f "package-lock.json" ]; then
      npm ci
    elif [ -f "package.json" ]; then
      npm install
    else
      echo "No JavaScript package manager files found, using Rails asset pipeline"
    fi

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
    # Rails SaaS Starter - Setup Complete! 🎉

    Your Rails SaaS application has been successfully generated with the core foundation.

    ## 🚀 Features Included (Core Foundation)

    - **Rails 8/Edge** with Hotwire (Turbo + Stimulus) and TailwindCSS.
    - **PostgreSQL** with `pgvector` extension for vector embeddings.
    - Basic `bin/setup` and `bin/dev` scripts.

    ## 🛠️ Getting Started

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

    ## 🧩 Extend Your Application with Modules

    This template is designed to be modular. You can add powerful features using the `bin/synth` CLI tool.

    **Available Modules:**

    - **Auth**: Comprehensive authentication with Devise, OmniAuth, and 2FA.
    - **Workspace**: Team and workspace management with slug routing, roles, and invitations.
    - **API**: JSON:API compliant endpoints and OpenAPI (Swagger) documentation.
    - **Deploy**: Deployment configurations for Fly.io, Render, and Kamal.
    - **AI**: Prompt templates, asynchronous LLM jobs, and Multi-Context Provider (MCP).
    - **Billing**: Stripe integration for subscriptions, invoices, and payments.
    - **CMS**: Content management system for blogs and static pages.
    - **I18n**: Internationalization and localization support.
    - **Admin**: Admin panel with user management, audit logs, and feature flags.
    - **Testing**: Comprehensive testing utilities and best practices.

    **To install a module:**

    ```bash
    bin/synth add <module_name>
    # Example: bin/synth add auth
    # Example: bin/synth add billing
    ```

    After installing a module, remember to run `rails db:migrate` if new migrations were added.

    ## 🎯 Next Steps

    1. Explore the available modules using `bin/synth list`.
    2. Install modules relevant to your application's needs.
    3. Customize the installed modules and core foundation.
    4. Set up monitoring and error tracking.

    Enjoy building your SaaS application! 🚀
  MD

  say ""
  say "✅ Rails SaaS Starter Template setup complete!"
  say ""
  say "📋 Next steps:"
  say "   1. cd into your application directory"
  say "   2. Run 'bin/setup' to complete configuration"  
  say "   3. Update .env with your actual values"
  say "   4. Run 'bin/dev' to start the development server"
  say ""
  say "📖 Check README_SETUP.md for detailed instructions"
  say ""
end