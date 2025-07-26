# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI module.

say_status :synth_ai, "Installing AI module with LLM job system"

# Add AI specific gems to the application's Gemfile
gem 'ruby-openai', '~> 7.0'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create an initializer for AI configuration
  initializer 'ai.rb', <<~'RUBY'
    # AI module configuration
    # Set your default model and any other AI related settings here
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4'
    Rails.application.config.ai.available_models = %w[gpt-4 gpt-3.5-turbo claude-3-opus claude-3-sonnet]
    Rails.application.config.ai.max_retries = 5
    Rails.application.config.ai.base_retry_delay = 5 # seconds
  RUBY

  # Copy LLM job system files
  directory 'app', 'app'
  directory 'config', 'config'
  directory 'db', 'db'
  directory 'test', 'test'

  # Add routes to the application
  route <<~'RUBY'
    # LLM job system routes
    resources :llm_outputs, only: [:index, :show] do
      member do
        post :feedback
        post :re_run
        post :regenerate
      end
    end

    # API routes for programmatic access
    namespace :api do
      namespace :v1 do
        resources :llm_outputs, only: [:index, :show] do
          member do
            post :feedback
            post :re_run
            post :regenerate
          end
        end

        # Endpoint to queue LLM jobs directly
        post 'llm_jobs', to: 'llm_jobs#create'
      end
    end
  RUBY

  # Run migrations
  rails_command 'db:migrate'

  # Add test helper to test_helper.rb if it exists
  if File.exist?('test/test_helper.rb')
    append_to_file 'test/test_helper.rb', <<~'RUBY'

      # LLM test helpers
      require 'test/support/llm_test_helper'
    RUBY
  end

  # Create .env.example entries if it exists
  if File.exist?('.env.example')
    append_to_file '.env.example', <<~'ENV'

      # LLM API Configuration
      OPENAI_API_KEY=your_openai_api_key_here
      ANTHROPIC_API_KEY=your_anthropic_api_key_here
      REDIS_URL=redis://localhost:6379/1
    ENV
  end

  say_status :synth_ai, "LLM job system installed successfully!"
  say_status :synth_ai, "Next steps:"
  say_status :synth_ai, "1. Configure your LLM API keys in .env"
  say_status :synth_ai, "2. Start Sidekiq: bundle exec sidekiq"
  say_status :synth_ai, "3. Queue your first job: LLMJob.perform_later(template: 'Hello {{name}}', model: 'gpt-4', context: { name: 'World' })"
  say_status :synth_ai, "4. Run tests: bin/rails test test/jobs/llm_job_test.rb"
end
