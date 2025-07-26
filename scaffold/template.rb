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
  
  # Add additional fields to User model for better seed data
  generate :migration, 'AddFieldsToUsers', 'first_name:string', 'last_name:string', 'admin:boolean'

  # Configure Sidekiq as the Active Job backend
  environment "config.active_job.queue_adapter = :sidekiq", env: %w[development production test]

  # Scaffold workspace/team models
  generate :model, 'Workspace', 'name:string', 'slug:string'
  generate :model, 'Membership', 'workspace:references', 'user:references', 'role:string'

  # Mount Sidekiq web UI behind authentication (requires admin? method on User)
  route "require 'sidekiq/web'\nauthenticate :user, lambda { |u| u.respond_to?(:admin?) && u.admin? } do\n  mount Sidekiq::Web => '/admin/sidekiq'\nend"

  # Set up comprehensive seeds and test fixtures
  say_status :seeds, "Setting up comprehensive seed data and test fixtures"
  
  # Copy main seeds file
  copy_file File.expand_path('lib/templates/db/seeds.rb', __dir__), 'db/seeds.rb'
  
  # Create seeds directory and copy module-specific seed files
  empty_directory 'db/seeds'
  copy_file File.expand_path('lib/templates/db/seeds/ai_seeds.rb', __dir__), 'db/seeds/ai_seeds.rb'
  copy_file File.expand_path('lib/templates/db/seeds/billing_seeds.rb', __dir__), 'db/seeds/billing_seeds.rb'
  copy_file File.expand_path('lib/templates/db/seeds/cms_seeds.rb', __dir__), 'db/seeds/cms_seeds.rb'
  
  # Copy factory files for consistent test data
  empty_directory 'test/factories'
  copy_file File.expand_path('lib/templates/test/factories/users.rb', __dir__), 'test/factories/users.rb'
  copy_file File.expand_path('lib/templates/test/factories/ai.rb', __dir__), 'test/factories/ai.rb'
  copy_file File.expand_path('lib/templates/test/factories/billing.rb', __dir__), 'test/factories/billing.rb'
  copy_file File.expand_path('lib/templates/test/factories/cms.rb', __dir__), 'test/factories/cms.rb'
  
  # Add FactoryBot configuration for Rails
  inject_into_file 'test/test_helper.rb', after: "class ActiveSupport::TestCase\n" do
    "  include FactoryBot::Syntax::Methods\n"
  end
  
  # Add seeds configuration note
  say_status :seeds, "✅ Seed files and factories installed!"
  say_status :seeds, "Run 'rails db:seed' after migrations to create demo data"
  say_status :seeds, "Demo user: demo@example.com / password123"

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
