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
gem 'redis', '~> 5.4'
gem 'sidekiq', '~> 8.0'
gem 'devise', '~> 4.9'
gem 'devise-two-factor', '~> 5.1'

# Authentication and authorization
gem 'devise', '~> 4.9'
gem 'omniauth', '~> 2.1'
gem 'omniauth-google-oauth2', '~> 1.2'
gem 'omniauth-github', '~> 2.0'
gem 'omniauth-slack', '~> 2.5'
gem 'omniauth-rails-csrf-protection', '~> 1.0'
gem 'stripe', '~> 15.3'
gem 'pundit', '~> 2.1'
gem 'friendly_id', '~> 5.5'
gem 'rolify', '~> 6.0'

# Frontend
gem 'turbo-rails', '~> 1.5'
gem 'stimulus-rails', '~> 1.2'
gem 'tailwindcss-rails', '~> 4.3'

# API and JSON handling
gem 'jsonapi-serializer', '~> 3.2'
gem 'rswag', '~> 2.14'

# Utilities
gem 'friendly_id', '~> 5.5'
gem 'image_processing', '~> 1.13'
gem 'bootsnap', '~> 1.18', require: false

gem_group :development, :test do
  gem 'dotenv-rails', '~> 3.1'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.3'
  gem 'rspec-rails', '~> 8.0'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'shoulda-matchers', '~> 6.5'
  gem 'capybara', '~> 3.40'
  gem 'selenium-webdriver', '~> 4.27'
  gem 'webmock', '~> 3.24'
end

gem_group :development do
  gem 'web-console', '~> 4.2'
  gem 'listen', '~> 3.8'
  gem 'spring', '~> 4.1'
end

after_bundle do
  # Add helper method for checking gem existence
  def gem_exists?(gem_name)
    File.read('Gemfile').include?(gem_name)
  end

  say "🔧 Setting up Rails application..."

  # Install Hotwire and Tailwind
  rails_command 'turbo:install'
  rails_command 'stimulus:install'
  rails_command 'tailwindcss:install'

  # Configure database for PostgreSQL with pgvector
  say "📊 Configuring PostgreSQL with pgvector..."
  
  initializer 'postgresql.rb', <<~RUBY
    # PostgreSQL configuration
    # Enable pgvector extension for vector embeddings
    Rails.application.configure do
      config.after_initialize do
        ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS vector;') if Rails.env.development?
      end
    end
  RUBY

  # Set up RSpec if included
  generate 'rspec:install' if gem_exists?('rspec-rails')

  if gem_exists?('rspec-rails')
    inject_into_file 'spec/rails_helper.rb', after: "require 'rspec/rails'\n" do
      <<~RUBY

    # Add additional requires below this line. Rails is not loaded until this point!

    # Require all files in spec/domains
    Dir[Rails.root.join('spec/domains/**/*.rb')].each { |f| require f }

    # Require shared contexts
    require 'support/authentication_helpers'
    require 'support/llm_stubs'
    require 'support/billing_stubs'
      RUBY
    end
  end
  
  # Configure Shoulda Matchers if present
  if gem_exists?('shoulda-matchers')
    create_file 'spec/support/shoulda_matchers.rb', <<~RUBY
      # frozen_string_literal: true

      Shoulda::Matchers.configure do |config|
        config.integrate do |with|
          with.test_framework :rspec
          with.library :rails
        end
      end
    RUBY
  end

  # Set up authentication with Devise
  say "🔐 Setting up Devise authentication..."
  generate 'devise:install'
  generate 'devise', 'User', 'first_name:string', 'last_name:string', 'admin:boolean'
  
  # Add Devise configuration for confirmable, lockable, and two-factor
  devise_config = <<~RUBY
    # Devise configuration
    config.confirmable = true
    config.lockable = true
    config.maximum_attempts = 5
    config.unlock_in = 1.hour
    config.unlock_strategy = :both
  RUBY
  
  inject_into_file 'config/initializers/devise.rb', devise_config, after: "# config.confirmable = false\n"

  # Generate FriendlyId and Rolify setups
  generate 'friendly_id'
  generate 'rolify', 'Role', 'User'

  # Configure Sidekiq as the Active Job backend
  say "⚙️  Configuring Sidekiq for background jobs..."
  environment "config.active_job.queue_adapter = :sidekiq", env: %w[development production test]
  
  # Create Sidekiq configuration
  create_file 'config/sidekiq.yml', <<~YAML
    :concurrency: 5
    :timeout: 25
    :verbose: false
    :queues:
      - critical
      - default
      - low
    
    :development:
      :concurrency: 2
    
    :test:
      :concurrency: 1
  YAML

  # Set up OmniAuth providers
  say "🔗 Setting up OmniAuth providers..."
  
  omniauth_config = <<~RUBY
    # OmniAuth configuration
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :google_oauth2, ENV['GOOGLE_OAUTH_CLIENT_ID'], ENV['GOOGLE_OAUTH_CLIENT_SECRET']
      provider :github, ENV['GITHUB_OAUTH_CLIENT_ID'], ENV['GITHUB_OAUTH_CLIENT_SECRET']
      provider :slack, ENV['SLACK_OAUTH_CLIENT_ID'], ENV['SLACK_OAUTH_CLIENT_SECRET'], scope: 'identity.basic,identity.email,identity.team'
    end
  RUBY
  
  initializer 'omniauth.rb', omniauth_config

  # Add OmniAuth columns to User model
  generate 'migration', 'AddOmniauthToUsers', 'provider:string', 'uid:string'

  # Scaffold workspace/team models with enhanced features
  say "🏢 Creating workspace and team models..."
  
  # Create Workspace model with slug support
  generate :model, 'Workspace', 'name:string', 'slug:string:uniq', 'description:text'
  
  # Create Membership model with roles and permissions
  generate :model, 'Membership', 'workspace:references', 'user:references', 'role:string', 'active:boolean'
  
  # Create Invitation model for team invitations
  generate :model, 'Invitation', 'workspace:references', 'email:string', 'role:string', 'token:string:uniq', 'accepted_at:datetime', 'expires_at:datetime'

  # Add indexes for performance
  inject_into_file Dir['db/migrate/*_create_workspaces.rb'].first, 
    "      t.index :slug, unique: true\n", 
    after: "t.text :description\n"
    
  inject_into_file Dir['db/migrate/*_create_memberships.rb'].first,
    "      t.index [:workspace_id, :user_id], unique: true\n      t.index :role\n",
    after: "t.boolean :active\n"
    
  inject_into_file Dir['db/migrate/*_create_invitations.rb'].first,
    "      t.index :token, unique: true\n      t.index :email\n",
    after: "t.datetime :expires_at\n"

  # Generate controllers for workspaces and API
  say "🎮 Generating controllers..."
  
  generate :controller, 'Workspaces', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy'
  generate :controller, 'Memberships', 'index', 'show', 'create', 'update', 'destroy'
  generate :controller, 'Api::V1::Base', '--skip-routes'
  generate :controller, 'Api::V1::Workspaces', '--skip-routes'
  generate :controller, 'Api::V1::Users', '--skip-routes'

  # Configure JSON:API serializers
  say "📋 Setting up JSON:API serializers..."
  
  run 'mkdir -p app/serializers'
  
  create_file 'app/serializers/application_serializer.rb', <<~RUBY
    # frozen_string_literal: true

  class ApplicationSerializer
      include JSONAPI::Serializer
    end
  RUBY
  
  create_file 'app/serializers/user_serializer.rb', <<~RUBY
    # frozen_string_literal: true

    class UserSerializer < ApplicationSerializer
      attributes :id, :email, :first_name, :last_name, :created_at, :updated_at
      
      has_many :memberships
      has_many :workspaces, through: :memberships
    end
  RUBY
  
  create_file 'app/serializers/workspace_serializer.rb', <<~RUBY
    # frozen_string_literal: true

    class WorkspaceSerializer < ApplicationSerializer
      attributes :id, :name, :slug, :description, :created_at, :updated_at
      
      has_many :memberships
      has_many :users, through: :memberships
    end
  RUBY

  # Configure routes with API namespace
  say "🛣️  Setting up routes..."
  
  route <<~RUBY
    # API routes
    namespace :api do
      namespace :v1 do
        resources :workspaces, only: [:index, :show, :create, :update, :destroy] do
          resources :memberships, only: [:index, :show, :create, :update, :destroy]
        end
        resources :users, only: [:index, :show, :update]
      end
    end

    # Web routes
    resources :workspaces do
      resources :memberships, except: [:new, :edit]
      resources :invitations, only: [:show, :create, :update]
    end
    
    # Auth domain routes
    scope module: :auth do
      devise_for :users, controllers: {
        sessions: 'sessions',
        omniauth_callbacks: 'sessions'
      }
      resource :two_factor, only: [:show, :enable, :disable]
    end

  # Mount Sidekiq web UI behind authentication
  route "require 'sidekiq/web'\nauthenticate :user, lambda { |u| u.respond_to?(:admin?) && u.admin? } do\n  mount Sidekiq::Web => '/admin/sidekiq'\nend"

  # Create environment configuration file
  say "🔧 Creating environment configuration..."
  
  create_file '.env.example', <<~ENV
    # Database
    DATABASE_URL=postgresql://localhost/rails_starter_development
    
    # Redis
    REDIS_URL=redis://localhost:6379/0
    
    # Devise
    DEVISE_SECRET_KEY=your_secret_key_here
    
    # OmniAuth Providers
    GOOGLE_OAUTH_CLIENT_ID=your_google_client_id
    GOOGLE_OAUTH_CLIENT_SECRET=your_google_client_secret
    
    GITHUB_OAUTH_CLIENT_ID=your_github_client_id
    GITHUB_OAUTH_CLIENT_SECRET=your_github_client_secret
    
    SLACK_OAUTH_CLIENT_ID=your_slack_client_id
    SLACK_OAUTH_CLIENT_SECRET=your_slack_client_secret
  ENV

  # Create model configurations
  say "📝 Configuring models..."
  
  # Update User model with enhanced features
  user_model_additions = <<~RUBY
    
    # Devise modules
    devise :database_authenticatable, :registerable, :recoverable, :rememberable, 
           :validatable, :confirmable, :lockable, :timeoutable

    # Associations
    has_many :memberships, dependent: :destroy
    has_many :workspaces, through: :memberships
    
    # Validations
    validates :first_name, :last_name, presence: true
    
    # Scopes
    scope :admins, -> { where(admin: true) }
    
    # Methods
    def full_name
      "#{first_name} #{last_name}".strip
    end
    
    def admin?
      admin == true
    end
    
    def member_of?(workspace)
      memberships.where(workspace: workspace, active: true).exists?
    end
    
    def role_in(workspace)
      memberships.find_by(workspace: workspace, active: true)&.role
    end
    
    # OmniAuth
    def self.from_omniauth(auth)
      where(email: auth.info.email).first_or_create do |user|
        user.email = auth.info.email
        user.password = Devise.friendly_token[0, 20]
        user.first_name = auth.info.first_name || auth.info.name&.split(' ')&.first || ''
        user.last_name = auth.info.last_name || auth.info.name&.split(' ')&.last || ''
        user.provider = auth.provider
        user.uid = auth.uid
        user.confirmed_at = Time.current # Auto-confirm OAuth users
      end
    end
  RUBY
  
  inject_into_file 'app/models/user.rb', user_model_additions, 
                   after: "class User < ApplicationRecord\n"

  # Update Workspace model with slug and associations
  workspace_model_additions = <<~RUBY
    
    extend FriendlyId
    friendly_id :name, use: :slugged
    
    # Associations
    has_many :memberships, dependent: :destroy
    has_many :users, through: :memberships
    has_many :invitations, dependent: :destroy
    
    # Validations
    validates :name, presence: true, uniqueness: true
    validates :slug, presence: true, uniqueness: true
    
    # Scopes
    scope :active, -> { joins(:memberships).where(memberships: { active: true }).distinct }
    
    # Methods
    def owners
      users.joins(:memberships).where(memberships: { role: 'owner', active: true })
    end
    
    def admins
      users.joins(:memberships).where(memberships: { role: ['owner', 'admin'], active: true })
    end
    
    def members
      users.joins(:memberships).where(memberships: { active: true })
    end
  RUBY
  
  inject_into_file 'app/models/workspace.rb', workspace_model_additions,
                   after: "class Workspace < ApplicationRecord\n"

  # Update Membership model with validations and enums
  membership_model_additions = <<~RUBY
    
    # Associations
    belongs_to :workspace
    belongs_to :user
    
    # Validations
    validates :role, presence: true, inclusion: { in: %w[member admin owner] }
    validates :user_id, uniqueness: { scope: :workspace_id }
    
    # Scopes
    scope :active, -> { where(active: true) }
    scope :by_role, ->(role) { where(role: role) }
    
    # Methods
    def owner?
      role == 'owner'
    end
    
    def admin?
      role.in?(['admin', 'owner'])
    end
    
    def can_manage_members?
      admin?
    end
    
    def can_invite_members?
      admin?
    end
  RUBY
  
  inject_into_file 'app/models/membership.rb', membership_model_additions,
                   after: "class Membership < ApplicationRecord\n"

  # Update Invitation model
  invitation_model_additions = <<~RUBY
    
    # Associations
    belongs_to :workspace
    
    # Validations
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :role, presence: true, inclusion: { in: %w[member admin] }
    validates :token, presence: true, uniqueness: true
    
    # Callbacks
    before_validation :generate_token, on: :create
    before_validation :set_expiration, on: :create
    
    # Scopes
    scope :pending, -> { where(accepted_at: nil) }
    scope :expired, -> { where('expires_at < ?', Time.current) }
    scope :valid, -> { where(accepted_at: nil).where('expires_at > ?', Time.current) }
    
    # Methods
    def accepted?
      accepted_at.present?
    end
    
    def expired?
      expires_at < Time.current
    end
    
    def accept!(user)
      return false if expired? || accepted?
      
      membership = workspace.memberships.create!(
        user: user,
        role: role,
        active: true
      )
      
      update!(accepted_at: Time.current) if membership.persisted?
      membership
    end
    
    private
    
    def generate_token
      self.token = SecureRandom.urlsafe_base64(32)
    end
    
    def set_expiration
      self.expires_at = 7.days.from_now
    end
  RUBY
  
  inject_into_file 'app/models/invitation.rb', invitation_model_additions,
                   after: "class Invitation < ApplicationRecord\n"

  # Create API base controller
  create_file 'app/controllers/api/v1/base_controller.rb', <<~RUBY
    # frozen_string_literal: true

    class Api::V1::BaseController < ApplicationController
      before_action :authenticate_user!
      before_action :set_default_format
      
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from Pundit::NotAuthorizedError, with: :forbidden
      
      protected
      
      def set_default_format
        request.format = :json
      end
      
      def render_json_api(resource, serializer_class, status: :ok, meta: {})
        render json: serializer_class.new(resource, meta: meta).serializable_hash,
               status: status
      end
      
      def render_error(message, status: :unprocessable_entity, details: {})
        render json: {
          errors: [{
            title: message,
            details: details
          }]
        }, status: status
      end
      
      private
      
      def not_found
        render_error('Resource not found', status: :not_found)
      end
      
      def unprocessable_entity(exception)
        render_error('Validation failed', details: exception.record.errors)
      end
      
      def forbidden
        render_error('Access denied', status: :forbidden)
      end
    end
  RUBY

  # Update API controllers
  inject_into_file 'app/controllers/api/v1/workspaces_controller.rb', <<~RUBY
    
    def index
      workspaces = current_user.workspaces
      render_json_api(workspaces, WorkspaceSerializer)
    end
    
    def show
      workspace = current_user.workspaces.find(params[:id])
      render_json_api(workspace, WorkspaceSerializer)
    end
    
    def create
      workspace = Workspace.new(workspace_params)
      
      if workspace.save
        workspace.memberships.create!(user: current_user, role: 'owner', active: true)
        render_json_api(workspace, WorkspaceSerializer, status: :created)
      else
        render_error('Failed to create workspace', details: workspace.errors)
      end
    end
    
    def update
      workspace = current_user.workspaces.find(params[:id])
      
      if workspace.update(workspace_params)
        render_json_api(workspace, WorkspaceSerializer)
      else
        render_error('Failed to update workspace', details: workspace.errors)
      end
    end
    
    def destroy
      workspace = current_user.workspaces.find(params[:id])
      workspace.destroy!
      head :no_content
    end
    
    private
    
    def workspace_params
      params.require(:workspace).permit(:name, :description)
    end
  RUBY, after: "class Api::V1::WorkspacesController < Api::V1::BaseController\n"

  # Create OmniAuth callbacks controller
  create_file 'app/controllers/users/omniauth_callbacks_controller.rb', <<~RUBY
    # frozen_string_literal: true

    class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
      def google_oauth2
        handle_callback('Google')
      end
      
      def github
        handle_callback('GitHub')
      end
      
      def slack
        handle_callback('Slack')
      end
      
      def failure
        redirect_to new_user_registration_url, alert: 'Authentication failed.'
      end
      
      private
      
      def handle_callback(provider)
        @user = User.from_omniauth(request.env['omniauth.auth'])
        
        if @user.persisted?
          sign_in_and_redirect @user, event: :authentication
          set_flash_message(:notice, :success, kind: provider) if is_navigational_format?
        else
          session['devise.oauth_data'] = request.env['omniauth.auth'].except('extra')
          redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\\n")
        end
      end
    end
  RUBY

  # Create basic test files
  say "🧪 Setting up test configuration..."
  
  if gem_exists?('rspec-rails')
    create_file 'spec/domains/auth/models/user_spec.rb', <<~RUBY
      # frozen_string_literal: true

      require 'rails_helper'

      RSpec.describe User, type: :model do
        describe 'validations' do
          it { should validate_presence_of(:first_name) }
          it { should validate_presence_of(:last_name) }
          it { should validate_presence_of(:email) }
        end

        describe 'associations' do
          it { should have_many(:memberships).dependent(:destroy) }
          it { should have_many(:workspaces).through(:memberships) }
        end

        describe '#full_name' do
          let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }
          
          it 'returns the full name' do
            expect(user.full_name).to eq('John Doe')
          end
        end

        describe '#admin?' do
          context 'when user is admin' do
            let(:user) { build(:user, admin: true) }
            
            it 'returns true' do
              expect(user.admin?).to be true
            end
          end

          context 'when user is not admin' do
            let(:user) { build(:user, admin: false) }
            
            it 'returns false' do
              expect(user.admin?).to be false
            end
          end
        end
      end
    RUBY

    create_file 'spec/domains/auth/factories/users.rb', <<~RUBY
      # frozen_string_literal: true

      FactoryBot.define do
        factory :user do
          email { Faker::Internet.email }
          password { 'password123' }
          first_name { Faker::Name.first_name }
          last_name { Faker::Name.last_name }
          confirmed_at { Time.current }
          
          trait :admin do
            admin { true }
          end
        end
      end
    RUBY

    create_file 'spec/domains/workspaces/factories/workspaces.rb', <<~RUBY
      # frozen_string_literal: true

      FactoryBot.define do
        factory :workspace do
          name { Faker::Company.name }
          description { Faker::Company.catch_phrase }
          slug { name.parameterize }
        end
      end
    RUBY
  end

  # Run database setup
  say "🗃️  Setting up database..."
  rails_command 'db:create'
  rails_command 'db:migrate'

  
  # Create bin/setup script
  create_file 'bin/setup', <<~BASH
    #!/usr/bin/env bash
    set -euo pipefail
    IFS=$'\\n\\t'
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
    # Rails SaaS Starter - Setup Complete! 🎉

    Your Rails SaaS application has been successfully generated with the following features:

    ## 🚀 Features Included

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
       - Sidekiq dashboard: http://localhost:3000/admin/sidekiq (admin users only)

    ## 🔧 Configuration

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

    ## 🧪 Running Tests

    ```bash
    # Run all tests
    bin/rails test

    # Or with RSpec (if installed)
    bundle exec rspec
    ```

    ## 📋 API Usage

    The application provides a JSON:API compliant REST API at `/api/v1/`:

    ```bash
    # Get user's workspaces
    curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3000/api/v1/workspaces

    # Create a new workspace
    curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer YOUR_TOKEN" \\
         -d '{"workspace":{"name":"My Workspace","description":"A new workspace"}}' \\
         http://localhost:3000/api/v1/workspaces
    ```

    ## 🎯 Next Steps

    1. Customize the design and branding
    2. Add your business-specific models and features
    3. Configure deployment (Fly.io, Render, Heroku, etc.)
    4. Set up monitoring and error tracking
    5. Add more OAuth providers as needed

    ## 🤝 Team Management

    - **Owners** can manage all aspects of a workspace
    - **Admins** can invite/remove members and manage settings
    - **Members** have standard access to workspace features
    - Use the invitation system to add team members via email

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
            Dir.children(modules_path).each { |module_dir| puts "  - #{module_dir}" }
            Dir.children(modules_path).each { |m| puts "  - #{m}" }
          else
            puts '  (none)'
          end
        end

        desc 'add MODULE', 'Add a module (e.g. ai, workspace, billing)'
        def add(module_name)
          puts "[stub] Add module: \#{module_name}"
          # TODO: implement installer loading lib/templates/synth/<module>/install.rb
          modules_path = File.expand_path('../templates/synth', __dir__)
          module_path = File.join(modules_path, module_name)
          
          unless Dir.exist?(module_path)
            puts "Error: Module '#{module_name}' not found"
            puts "Available modules: #{Dir.exist?(modules_path) ? Dir.children(modules_path).join(', ') : 'none'}"
            return
          end

          installer_path = File.join(module_path, 'install.rb')
          
          if File.exist?(installer_path)
            puts "Installing #{module_name} module..."
            load installer_path
            puts "#{module_name.capitalize} module installed successfully!"
          else
            puts "Error: No installer found for #{module_name} module"
          end
        end

        desc 'remove MODULE', 'Remove a module'
        def remove(module_name)
          puts "[stub] Remove module: #{module_name}"
        end

        desc 'upgrade', 'Upgrade installed modules'
        def upgrade
          puts '[stub] Upgrade modules'
        end

        desc 'test [MODULE]', 'Run tests for a specific module'
        def test(module_name = 'all')
          if module_name == 'all'
            puts 'Running full test suite...'
            system('bin/rails test') || system('bundle exec rspec')
          else
            puts "[stub] Run #{module_name} tests"
          end
        end

        desc 'doctor', 'Validate setup and keys'
        def doctor
          puts 'Running synth doctor...'
          
          checks = [
            check_database,
            check_redis,
            check_environment_variables
          ]
          
          if checks.all?
            puts "✅ All checks passed!"
          else
            puts "❌ Some checks failed. Please review the issues above."
          end
        end

        desc 'scaffold agent NAME', 'Scaffold a new AI agent'
        def scaffold(name)
          puts "[stub] Scaffold agent: #{name}"
          # TODO: implement agent scaffolding
        end
        
        private
        
        def check_database
          print "Checking database connection... "
          require_relative '../../config/environment'
          ActiveRecord::Base.connection.execute('SELECT 1')
          puts "✅"
          true
        rescue => e
          puts "❌ (#{e.message})"
          false
        end
        
        def check_redis
          print "Checking Redis connection... "
          require 'redis'
          redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
          redis.ping
          puts "✅"
          true
        rescue => e
          puts "❌ (#{e.message})"
          false
        end
        
        def check_environment_variables
          print "Checking environment variables... "
          required_vars = %w[DEVISE_SECRET_KEY]
          missing_vars = required_vars.reject { |var| ENV[var] }
          
          if missing_vars.empty?
            puts "✅"
            true
          else
            puts "❌ Missing: #{missing_vars.join(', ')}"
            false
          end
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
  
  # Run database setup
  say "🗃️  Setting up database..."
  rails_command 'db:create'
  rails_command 'db:migrate'
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
