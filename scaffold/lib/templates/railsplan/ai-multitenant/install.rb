# frozen_string_literal: true

# Synth AI Multitenant module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI multitenant module.

say_status :railsplan_ai_multitenant, "Installing AI Multitenant module with complete workspace isolation"

# Add AI specific gems to the application's Gemfile
add_gem 'ruby-openai', '~> 7.0'
add_gem 'anthropic', '~> 0.3.0'  
add_gem 'paper_trail'
add_gem 'whenever'
add_gem 'chartkick'
add_gem 'groupdate'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create domain-specific directories
  run 'mkdir -p app/controllers/ai app/models app/views/ai'
  run 'mkdir -p test/models test/controllers test/jobs test/services'
  run 'mkdir -p app/jobs app/services'
  
  # Create AI multitenant configuration
  initializer 'ai_multitenant.rb', <<~'RUBY'
    # AI Multitenant module configuration
    Rails.application.config.ai_multitenant = ActiveSupport::OrderedOptions.new
    
    # Default AI settings
    Rails.application.config.ai_multitenant.default_model = 'gpt-4'
    Rails.application.config.ai_multitenant.default_temperature = 0.7
    Rails.application.config.ai_multitenant.max_tokens = 4096
    
    # Supported output formats
    Rails.application.config.ai_multitenant.output_formats = %w[text json markdown html].freeze
    
    # Usage tracking settings
    Rails.application.config.ai_multitenant.track_usage = true
    Rails.application.config.ai_multitenant.daily_summary_hour = 2
    
    # Rate limiting per workspace (requests per hour)
    Rails.application.config.ai_multitenant.rate_limit = 1000
    
    # Playground settings
    Rails.application.config.ai_multitenant.playground_enabled = true
    Rails.application.config.ai_multitenant.playground_models = {
      'openai' => ['gpt-3.5-turbo', 'gpt-4', 'gpt-4-turbo'],
      'anthropic' => ['claude-3-haiku', 'claude-3-sonnet', 'claude-3-opus']
    }
  RUBY

  # Set up PaperTrail for versioning if not already configured
  unless File.exist?('config/initializers/paper_trail.rb')
    initializer 'paper_trail.rb', <<~'RUBY'
      PaperTrail.config.track_associations = false
      PaperTrail.config.association_reify_error_behaviour = :warn
    RUBY
  end

  # Copy core models with enhanced multitenant features
  copy_file File.join(__dir__, 'app/models/ai_provider.rb'), 'app/models/ai_provider.rb'
  copy_file File.join(__dir__, 'app/models/ai_credential.rb'), 'app/models/ai_credential.rb'
  copy_file File.join(__dir__, 'app/models/ai_credential_test.rb'), 'app/models/ai_credential_test.rb'
  copy_file File.join(__dir__, 'app/models/ai_usage_summary.rb'), 'app/models/ai_usage_summary.rb'
  copy_file File.join(__dir__, 'app/models/prompt_template.rb'), 'app/models/prompt_template.rb'
  copy_file File.join(__dir__, 'app/models/prompt_execution.rb'), 'app/models/prompt_execution.rb'
  copy_file File.join(__dir__, 'app/models/llm_output.rb'), 'app/models/llm_output.rb'

  # Copy enhanced LLMJob with workspace support
  copy_file File.join(__dir__, 'app/jobs/llm_job.rb'), 'app/jobs/llm_job.rb'
  copy_file File.join(__dir__, 'app/jobs/ai_usage_summary_job.rb'), 'app/jobs/ai_usage_summary_job.rb'

  # Copy services
  copy_file File.join(__dir__, 'app/services/ai_provider_test_service.rb'), 'app/services/ai_provider_test_service.rb'
  copy_file File.join(__dir__, 'app/services/workspace_llm_job_runner.rb'), 'app/services/workspace_llm_job_runner.rb'

  # Copy migrations
  copy_file File.join(__dir__, 'db/migrate/001_create_ai_providers.rb'), 'db/migrate/001_create_ai_providers.rb'
  copy_file File.join(__dir__, 'db/migrate/002_create_ai_credentials.rb'), 'db/migrate/002_create_ai_credentials.rb'
  copy_file File.join(__dir__, 'db/migrate/003_create_prompt_templates.rb'), 'db/migrate/003_create_prompt_templates.rb'
  copy_file File.join(__dir__, 'db/migrate/004_create_prompt_executions.rb'), 'db/migrate/004_create_prompt_executions.rb'
  copy_file File.join(__dir__, 'db/migrate/005_create_llm_outputs.rb'), 'db/migrate/005_create_llm_outputs.rb'
  copy_file File.join(__dir__, 'db/migrate/006_create_ai_usage_summaries.rb'), 'db/migrate/006_create_ai_usage_summaries.rb'
  copy_file File.join(__dir__, 'db/migrate/007_create_versions.rb'), 'db/migrate/007_create_versions.rb'
  copy_file File.join(__dir__, 'db/migrate/008_create_ai_credential_tests.rb'), 'db/migrate/008_create_ai_credential_tests.rb'

  # Copy controllers for AI management and playground
  copy_file File.join(__dir__, 'app/controllers/ai/base_controller.rb'), 'app/controllers/ai/base_controller.rb'
  copy_file File.join(__dir__, 'app/controllers/ai/playground_controller.rb'), 'app/controllers/ai/playground_controller.rb'
  copy_file File.join(__dir__, 'app/controllers/ai/analytics_controller.rb'), 'app/controllers/ai/analytics_controller.rb'
  copy_file File.join(__dir__, 'app/controllers/ai/credentials_controller.rb'), 'app/controllers/ai/credentials_controller.rb'
  copy_file File.join(__dir__, 'app/controllers/ai/providers_controller.rb'), 'app/controllers/ai/providers_controller.rb'

  # Add routes for AI multitenant features
  route <<~'RUBY'
    # AI Multitenant routes
    namespace :ai do
      get 'playground', to: 'playground#index'
      post 'playground/execute', to: 'playground#execute'
      get 'analytics', to: 'analytics#index'
      get 'analytics/usage', to: 'analytics#usage_data'
      
      resources :credentials do
        member do
          post :test_connection
          post :set_default
        end
      end
      
      resources :providers, only: [:index, :show] do
        member do
          post :test
        end
      end
      
      resources :prompt_templates do
        member do
          post :preview
          get :diff
          post :publish
        end
        resources :prompt_executions, only: [:index, :show, :create]
      end
    end
  RUBY

  # Copy views for AI playground and management
  run 'mkdir -p app/views/ai/playground app/views/ai/analytics app/views/ai/credentials'
  copy_file File.join(__dir__, 'app/views/ai/playground/index.html.erb'), 'app/views/ai/playground/index.html.erb'
  copy_file File.join(__dir__, 'app/views/ai/analytics/index.html.erb'), 'app/views/ai/analytics/index.html.erb'

  # Copy seed data with default OpenAI provider
  copy_file File.join(__dir__, 'db/seeds/ai_multitenant.rb'), 'db/seeds/ai_multitenant.rb'

  # Add to main seeds file
  append_to_file 'db/seeds.rb', <<~'RUBY'
    
    # Load AI Multitenant module seeds
    load Rails.root.join('db', 'seeds', 'ai_multitenant.rb') if File.exist?(Rails.root.join('db', 'seeds', 'ai_multitenant.rb'))
  RUBY

  # Copy comprehensive test files
  copy_file File.join(__dir__, 'test/models/ai_provider_test.rb'), 'test/models/ai_provider_test.rb'
  copy_file File.join(__dir__, 'test/models/ai_credential_test.rb'), 'test/models/ai_credential_test.rb'
  copy_file File.join(__dir__, 'test/models/ai_usage_summary_test.rb'), 'test/models/ai_usage_summary_test.rb'
  copy_file File.join(__dir__, 'test/jobs/llm_job_test.rb'), 'test/jobs/llm_job_test.rb'
  copy_file File.join(__dir__, 'test/jobs/ai_usage_summary_job_test.rb'), 'test/jobs/ai_usage_summary_job_test.rb'
  copy_file File.join(__dir__, 'test/services/workspace_llm_job_runner_test.rb'), 'test/services/workspace_llm_job_runner_test.rb'
  copy_file File.join(__dir__, 'test/controllers/ai/playground_controller_test.rb'), 'test/controllers/ai/playground_controller_test.rb'
  copy_file File.join(__dir__, 'test/controllers/ai/playground_controller_test.rb'), 'test/controllers/ai/playground_controller_test.rb'

  # Set up whenever for cron jobs
  if File.exist?('config/schedule.rb')
    append_to_file 'config/schedule.rb', <<~'RUBY'
      
      # AI usage summary job - runs daily at 2 AM
      every 1.day, at: '2:00 am' do
        runner "AiUsageSummaryJob.perform_later"
      end
    RUBY
  else
    create_file 'config/schedule.rb', <<~'RUBY'
      # Use this file to easily define all of your cron jobs.
      
      # AI usage summary job - runs daily at 2 AM
      every 1.day, at: '2:00 am' do
        runner "AiUsageSummaryJob.perform_later"
      end
      
      # Update crontab with: whenever --update-crontab
    RUBY
  end

  say_status :railsplan_ai_multitenant, "AI Multitenant system installed successfully!"
  say_status :railsplan_ai_multitenant, ""
  say_status :railsplan_ai_multitenant, "Next steps after installation:"
  say_status :railsplan_ai_multitenant, "1. Run 'rails db:migrate' to create database tables"
  say_status :railsplan_ai_multitenant, "2. Run 'rails db:seed' to set up default OpenAI provider"
  say_status :railsplan_ai_multitenant, "3. Set OPENAI_API_KEY in your environment"
  say_status :railsplan_ai_multitenant, "4. Visit /ai/playground to test the AI playground"
  say_status :railsplan_ai_multitenant, "5. Run 'whenever --update-crontab' to enable usage summaries"
  say_status :railsplan_ai_multitenant, "6. Run 'rails test' to verify everything works"
end