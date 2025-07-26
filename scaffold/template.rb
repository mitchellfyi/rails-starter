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
gem 'pgvector', '~> 0.3.2'
gem 'redis', '~> 5.4'
gem 'sidekiq', '~> 8.0'
gem 'devise', '~> 4.9'
gem 'devise-two-factor', '~> 5.1'

gem 'omniauth', '~> 2.1'
gem 'omniauth-google-oauth2', '~> 1.2'
gem 'omniauth-github', '~> 2.0'
gem 'omniauth-slack', '~> 2.5'
gem 'omniauth-rails-csrf-protection', '~> 1.0'
gem 'stripe', '~> 15.3'
gem 'pundit', '~> 2.1'
gem 'friendly_id', '~> 5.5'
gem 'rolify', '~> 6.0'
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

  # Generate FriendlyId and Rolify setups
  generate 'friendly_id'
  generate 'rolify', 'Role', 'User'

  # Configure Sidekiq as the Active Job backend
  environment "config.active_job.queue_adapter = :sidekiq", env: %w[development production test]

  # Scaffold workspace/team models
  generate :model, 'Workspace', 'name:string', 'slug:string'
  generate :model, 'Membership', 'workspace:references', 'user:references', 'role:string'

  # Generate Invitation model for workspace invitations
  generate :model, 'Invitation', 'sender:references', 'recipient_email:string', 'token:string', 'workspace:references', 'status:string'

  # Generate controllers for workspace management
  generate :controller, 'Workspaces', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy'
  generate :controller, 'Memberships', 'index', 'create', 'destroy'
  generate :controller, 'Invitations', 'create', 'show', 'accept', 'reject'

  # Configure models with enhanced functionality
  inject_into_file 'app/models/workspace.rb', after: "class Workspace < ApplicationRecord\n" do
    <<~RUBY
      extend FriendlyId
      friendly_id :name, use: :slugged
      
      has_many :memberships, dependent: :destroy
      has_many :users, through: :memberships
      has_many :invitations, dependent: :destroy
      
      validates :name, presence: true, uniqueness: true
    RUBY
  end

  inject_into_file 'app/models/membership.rb', after: "class Membership < ApplicationRecord\n" do
    <<~RUBY
      belongs_to :workspace
      belongs_to :user
      
      validates :role, presence: true, inclusion: { in: %w[admin member viewer] }
      validates :user_id, uniqueness: { scope: :workspace_id }
    RUBY
  end

  inject_into_file 'app/models/invitation.rb', after: "class Invitation < ApplicationRecord\n" do
    <<~RUBY
      belongs_to :sender, class_name: 'User'
      belongs_to :workspace
      
      validates :recipient_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
      validates :token, presence: true, uniqueness: true
      validates :status, presence: true, inclusion: { in: %w[pending accepted rejected] }
      
      before_validation :generate_token, on: :create
      
      scope :pending, -> { where(status: 'pending') }
      
      def accept!
        update!(status: 'accepted')
      end
      
      def reject!
        update!(status: 'rejected')
      end
      
      private
      
      def generate_token
        require 'securerandom'
        self.token = SecureRandom.urlsafe_base64(32) if token.blank?
      end
    RUBY
  end

  inject_into_file 'app/models/user.rb', after: "class User < ApplicationRecord\n" do
    <<~RUBY
      rolify
      devise :two_factor_authenticatable,
             :otp_secret_encryption_key => Rails.application.credentials.secret_key_base
      
      has_many :memberships, dependent: :destroy
      has_many :workspaces, through: :memberships
      has_many :sent_invitations, class_name: 'Invitation', foreign_key: 'sender_id', dependent: :destroy
      
      def admin?
        has_role?(:admin)
      end
    RUBY
  end

  # Configure routes for slug-based workspace routing
  route "resources :workspaces, param: :slug do\n    resources :memberships\n    resources :invitations\n  end"

  # Configure Devise for 2FA and OmniAuth providers
  initializer 'omniauth.rb', <<~RUBY
    Rails.application.config.to_prepare do
      Devise.setup do |config|
        config.omniauth :google_oauth2, Rails.application.credentials.dig(:google, :client_id), Rails.application.credentials.dig(:google, :client_secret)
        config.omniauth :github, Rails.application.credentials.dig(:github, :client_id), Rails.application.credentials.dig(:github, :client_secret), scope: 'user:email'
        config.omniauth :slack, Rails.application.credentials.dig(:slack, :client_id), Rails.application.credentials.dig(:slack, :client_secret)
      end
    end
  RUBY

  # Configure Sidekiq as the Active Job backend
  environment "config.active_job.queue_adapter = :sidekiq", env: %w[development production test]

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
            Dir.children(modules_path).each { |module_dir| puts "  - \#{module_dir}" }
          else
            puts '  (none)'
          end
        end

        desc 'add MODULE', 'Add a module (e.g. billing, ai)'
        def add(module_name)
          puts "[stub] Add module: \#{module_name}"
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
          puts "[stub] Scaffold agent: \#{name}"
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
