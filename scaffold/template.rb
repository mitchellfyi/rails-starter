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

  # Create GitHub Actions workflow template for CI with API schema validation
  run 'mkdir -p .github/workflows'
  create_file '.github/workflows/test.yml', <<~YAML
    name: Test Suite

    on:
      push:
        branches: [ main, develop ]
      pull_request:
        branches: [ main, develop ]

    jobs:
      test:
        runs-on: ubuntu-latest

        services:
          postgres:
            image: postgres:15
            env:
              POSTGRES_PASSWORD: postgres
            options: >-
              --health-cmd pg_isready
              --health-interval 10s
              --health-timeout 5s
              --health-retries 5
            ports:
              - 5432:5432

          redis:
            image: redis:7
            options: >-
              --health-cmd "redis-cli ping"
              --health-interval 10s
              --health-timeout 5s
              --health-retries 5
            ports:
              - 6379:6379

        steps:
        - uses: actions/checkout@v4

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            ruby-version: '3.2'
            bundler-cache: true

        - name: Set up Node.js
          uses: actions/setup-node@v4
          with:
            node-version: '18'
            cache: 'yarn'

        - name: Install dependencies
          run: |
            bundle install
            yarn install

        - name: Set up database
          env:
            DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
            RAILS_ENV: test
          run: |
            bundle exec rails db:setup

        - name: Run tests
          env:
            DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
            RAILS_ENV: test
          run: |
            bundle exec rspec

        - name: Validate API schema
          env:
            DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
            RAILS_ENV: test
          run: |
            if [ -f lib/tasks/api.rake ]; then
              bundle exec rake api:validate_schema
            else
              echo "API module not installed, skipping schema validation"
            fi

        - name: Upload API schema
          if: github.ref == 'refs/heads/main'
          uses: actions/upload-artifact@v4
          with:
            name: api-schema
            path: swagger/
  YAML
end

say "✅ Template setup complete.  Run `bin/setup` to finish configuring your application."
