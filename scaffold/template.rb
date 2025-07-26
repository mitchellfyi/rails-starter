# frozen_string_literal: true

# Template script for generating a new Rails SaaS Starter application.
#
# Usage:
#   rails new myapp --dev -m https://example.com/template.rb
#
# This script will guide you through setting up the base stack for the
# Rails SaaS Starter Template.  It appends necessary gems to your
# Gemfile, runs generators for authentication, background jobs, and
# Tailwind/Hotwire, and scaffolds workspace/team models.  It also
# installs a command‑line interface (`bin/synth`) and a default AI
# module skeleton.  Feel free to customise this script to suit your
# project's needs.

# Check Ruby version
ruby_version = Gem::Version.new(RUBY_VERSION)
required_ruby_version = Gem::Version.new('3.1.0')

if ruby_version < required_ruby_version
  say "❌ Ruby #{required_ruby_version} or higher is required. You have #{ruby_version}.", :red
  exit 1
end

# Check Rails version
rails_version = Gem::Version.new(Rails::VERSION::STRING)
required_rails_version = Gem::Version.new('7.0.0')

if rails_version < required_rails_version
  say "❌ Rails #{required_rails_version} or higher is required. You have #{rails_version}.", :red
  exit 1
end

say "🪝 Setting up Rails SaaS Starter Template..."
say "   Ruby: #{ruby_version}"
say "   Rails: #{rails_version}"

# Add gems to the Gemfile
gem 'pg', '~> 1.5'
gem 'pgvector', '~> 0.5'
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
gem 'thor', '~> 1.0'

gem_group :development, :test do
  gem 'dotenv-rails', '~> 3.1'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.3'
  gem 'rspec-rails', '~> 8.0'
end

after_bundle do
  # Create environment file from example
  copy_file '.env.example', '.env' if File.exist?('.env.example')
  
  # Create basic .env.example file
  create_file '.env.example', <<~ENV
    # Database
    DATABASE_URL=postgresql://localhost/myapp_development
    
    # Redis
    REDIS_URL=redis://localhost:6379/1
    
    # Devise secret key (generate with: rails secret)
    DEVISE_SECRET_KEY=changeme
    
    # OpenAI API (for AI module)
    OPENAI_API_KEY=your_openai_api_key_here
    
    # Stripe API (for billing module)
    STRIPE_PUBLISHABLE_KEY=pk_test_your_key_here
    STRIPE_SECRET_KEY=sk_test_your_key_here
  ENV

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

  # Create synth module directory structure
  run 'mkdir -p lib/synth'
  run 'mkdir -p lib/templates/synth'

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
            Dir.children(modules_path).each { |m| puts "  - \#{m}" }
          else
            puts '  (none)'
          end
        end

        desc 'add MODULE', 'Add a module (e.g. billing, ai)'
        def add(module_name)
          module_path = File.expand_path("../templates/synth/\#{module_name}", __dir__)
          install_file = File.join(module_path, 'install.rb')
          
          if File.exist?(install_file)
            puts "Installing \#{module_name} module..."
            load install_file
          else
            puts "Module \#{module_name} not found at \#{install_file}"
          end
        end

        desc 'remove MODULE', 'Remove a module'
        def remove(module_name)
          puts "[stub] Remove module: \#{module_name}"
        end

        desc 'upgrade', 'Upgrade installed modules'
        def upgrade
          puts '[stub] Upgrade modules'
        end

        desc 'test MODULE', 'Run tests for a specific module'
        def test(module_name = nil)
          if module_name
            puts "Running tests for \#{module_name} module..."
            system("bundle exec rspec spec/\#{module_name}") if Dir.exist?("spec/\#{module_name}")
          else
            puts 'Running full test suite...'
            system('bundle exec rspec')
          end
        end

        desc 'doctor', 'Validate setup and keys'
        def doctor
          puts 'Running synth doctor...'
          puts '✅ Ruby version: ' + RUBY_VERSION
          puts '✅ Rails version: ' + Rails::VERSION::STRING if defined?(Rails)
          puts '⚠️  Add other environment checks here'
        end

        desc 'scaffold AGENT_NAME', 'Scaffold a new AI agent'
        def scaffold(agent_name)
          puts "Scaffolding agent: \#{agent_name}"
          # TODO: Generate agent files
        end
      end
    end
  RUBY

  # Create directory structure for modules and seeds
  run 'mkdir -p db/seeds'
  
  # Run database migrations
  rails_command 'db:create'
  rails_command 'db:migrate'
  
  # Initialize Git repository if not already done
  git :init unless File.exist?('.git')
  git add: '.'
  git commit: '-m "Initial commit: Rails SaaS Starter Template"'
end

say "✅ Template setup complete!"
say ""
say "Next steps:"
say "  1. Copy .env.example to .env and configure your environment variables"
say "  2. Run 'bin/setup' to finish configuring your application"
say "  3. Run 'bin/dev' to start your development server"
say "  4. Try 'bin/synth list' to see available modules"
say "  5. Run 'bin/synth add ai' to install the AI module"