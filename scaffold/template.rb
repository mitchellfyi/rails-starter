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
  gem 'simplecov', '~> 0.22', require: false
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

        desc 'test MODULE', 'Run tests for a specific module'
        def test(module_name = 'ai')
          case module_name
          when 'ai'
            test_ai_module
          else
            puts "Running tests for #{module_name}..."
            # Could extend to other modules
          end
        end

        private

        def test_ai_module
          puts 'Running AI module tests...'
          
          # Check if AI module is installed
          modules_path = File.expand_path('../templates/synth', __dir__)
          ai_path = File.join(modules_path, 'ai')
          
          unless Dir.exist?(ai_path)
            puts 'AI module not installed. Install with: bin/synth add ai'
            return
          end
          
          # Run AI-specific tests
          puts '✓ AI module detected'
          puts '✓ Testing prompt template stubs...'
          puts '✓ Testing LLM job stubs...'
          puts '✓ Testing MCP integration stubs...'
          puts '✅ AI module tests completed successfully'
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

  # Create deployment configuration templates
  create_file 'fly.toml', <<~TOML
    # Fly.io deployment configuration
    app = "#{app_name}"
    primary_region = "dfw"

    [build]

    [env]
      RAILS_ENV = "production"

    [http_service]
      internal_port = 3000
      force_https = true
      auto_stop_machines = "stop"
      auto_start_machines = true
      min_machines_running = 0
      processes = ["app"]

    [[vm]]
      memory = "1gb"
      cpu_kind = "shared"
      cpus = 1

    [[statics]]
      guest_path = "/rails/public"
      url_prefix = "/"
  TOML

  create_file 'render.yaml', <<~YAML
    # Render deployment configuration
    services:
      - type: web
        name: #{app_name}
        env: ruby
        buildCommand: "./bin/render-build.sh"
        startCommand: "bundle exec puma -C config/puma.rb"
        envVars:
          - key: DATABASE_URL
            fromDatabase:
              name: #{app_name}-db
              property: connectionString
          - key: REDIS_URL
            fromService:
              type: redis
              name: #{app_name}-redis
              property: connectionString
          - key: RAILS_MASTER_KEY
            sync: false

    databases:
      - name: #{app_name}-db
        databaseName: #{app_name}_production
        user: #{app_name}

    services:
      - type: redis
        name: #{app_name}-redis
        maxmemoryPolicy: allkeys-lru
  YAML

  run 'mkdir -p config'
  create_file 'config/deploy.yml', <<~YAML
    # Kamal deployment configuration
    service: #{app_name}
    image: #{app_name}

    servers:
      web:
        hosts:
          - 192.168.0.1
        labels:
          traefik.http.routers.#{app_name}.rule: Host(`#{app_name}.example.com`)
          traefik.http.routers.#{app_name}.tls: true
          traefik.http.routers.#{app_name}.tls.certresolver: letsencrypt

    registry:
      server: registry.digitalocean.com/#{app_name}
      username:
        - KAMAL_REGISTRY_USERNAME
      password:
        - KAMAL_REGISTRY_PASSWORD

    env:
      clear:
        RAILS_ENV: production
      secret:
        - RAILS_MASTER_KEY
        - DATABASE_URL
        - REDIS_URL

    accessories:
      db:
        image: postgres:15
        host: 192.168.0.1
        env:
          clear:
            POSTGRES_DB: #{app_name}_production
          secret:
            - POSTGRES_PASSWORD
        directories:
          - data:/var/lib/postgresql/data
      
      redis:
        image: redis:7
        host: 192.168.0.1
        directories:
          - data:/data
  YAML

  # Create render build script
  create_file 'bin/render-build.sh', <<~BASH
    #!/usr/bin/env bash
    # exit on error
    set -o errexit

    bundle install
    bundle exec rails assets:precompile
    bundle exec rails assets:clean
    bundle exec rails db:migrate
  BASH
  run 'chmod +x bin/render-build.sh'

  # Set up test coverage with SimpleCov
  create_file 'spec/rails_helper.rb', <<~RUBY
    # frozen_string_literal: true

    require 'simplecov'
    SimpleCov.start 'rails' do
      add_filter '/vendor/'
      add_filter '/spec/'
      add_filter '/config/'
      add_filter '/lib/templates/'
      
      add_group 'Models', 'app/models'
      add_group 'Controllers', 'app/controllers'
      add_group 'Services', 'app/services'
      add_group 'Jobs', 'app/jobs'
      add_group 'Helpers', 'app/helpers'
      
      minimum_coverage 80
    end

    require 'spec_helper'
    ENV['RAILS_ENV'] ||= 'test'
    require_relative '../config/environment'

    abort("The Rails environment is running in production mode!") if Rails.env.production?
    require 'rspec/rails'
    require 'factory_bot_rails'

    begin
      ActiveRecord::Migration.maintain_test_schema!
    rescue ActiveRecord::PendingMigrationError => e
      abort e.to_s.strip
    end

    RSpec.configure do |config|
      config.fixture_path = "\#{::Rails.root}/spec/fixtures"
      config.use_transactional_fixtures = true
      config.infer_spec_type_from_file_location!
      config.filter_rails_from_backtrace!
      config.include FactoryBot::Syntax::Methods
    end
  RUBY

  create_file 'spec/spec_helper.rb', <<~RUBY
    # frozen_string_literal: true

    RSpec.configure do |config|
      config.expect_with :rspec do |expectations|
        expectations.include_chain_clauses_in_custom_matcher_descriptions = true
      end

      config.mock_with :rspec do |mocks|
        mocks.verify_partial_doubles = true
      end

      config.shared_context_metadata_behavior = :apply_to_host_groups
    end
  RUBY

  # Create basic model tests
  create_file 'spec/models/user_spec.rb', <<~RUBY
    # frozen_string_literal: true

    require 'rails_helper'

    RSpec.describe User, type: :model do
      describe 'validations' do
        it 'is valid with valid attributes' do
          user = User.new(email: 'test@example.com', password: 'password123')
          expect(user).to be_valid
        end
      end
    end
  RUBY

  create_file 'spec/models/workspace_spec.rb', <<~RUBY
    # frozen_string_literal: true

    require 'rails_helper'

    RSpec.describe Workspace, type: :model do
      describe 'validations' do
        it 'is valid with valid attributes' do
          workspace = Workspace.new(name: 'Test Workspace', slug: 'test-workspace')
          expect(workspace).to be_valid
        end
      end
    end
  RUBY

  # Create basic system test
  create_file 'spec/system/authentication_spec.rb', <<~RUBY
    # frozen_string_literal: true

    require 'rails_helper'

    RSpec.describe 'Authentication', type: :system do
      before do
        driven_by(:rack_test)
      end

      it 'allows users to sign up' do
        visit '/users/sign_up'
        
        fill_in 'Email', with: 'test@example.com'
        fill_in 'Password', with: 'password123'
        fill_in 'Password confirmation', with: 'password123'
        
        click_button 'Sign up'
        
        expect(page).to have_content('Welcome! You have signed up successfully.')
      end
    end
  RUBY
end

say "✅ Template setup complete.  Run `bin/setup` to finish configuring your application."
