# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI module.

say_status :synth_ai, "Installing AI module"

# Add AI specific gems to the application's Gemfile
add_gem 'ruby-openai'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create an initializer for AI configuration
  initializer 'ai.rb', <<~'RUBY'
    # AI module configuration
    # Set your default model and any other AI related settings here
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4'
  RUBY

  # Generate models for prompt templates and LLM jobs
  say_status :synth_ai, "Generating AI models and migrations"
  
  # Prompt Template model
  generate :model, 'PromptTemplate', 
    'name:string:index',
    'description:text',
    'content:text',
    'tags:text', # JSON array
    'variables:text', # JSON array  
    'output_format:string',
    'version:integer',
    'workspace:references'
    
  # LLM Job model for async job processing
  generate :model, 'LLMJob',
    'prompt_template:references',
    'user:references',
    'workspace:references',
    'model:string',
    'context:text', # JSON
    'status:string:index',
    'started_at:datetime',
    'completed_at:datetime',
    'failed_at:datetime',
    'error_message:text',
    'retry_count:integer'
    
  # LLM Output model for storing results
  generate :model, 'LLMOutput',
    'llm_job:references',
    'content:text',
    'tokens_used:integer',
    'cost_cents:integer',
    'feedback_rating:integer', # -1, 0, 1 for thumbs down, none, thumbs up
    'feedback_comment:text'

  # Add indexes and constraints
  create_file 'db/migrate/add_ai_indexes.rb', <<~RUBY
    class AddAiIndexes < ActiveRecord::Migration[7.1]
      def change
        add_index :prompt_templates, [:workspace_id, :name], unique: true
        add_index :llm_jobs, [:user_id, :created_at]
        add_index :llm_jobs, [:workspace_id, :status]
        add_index :llm_outputs, :llm_job_id, unique: true
      end
    end
  RUBY

  say_status :synth_ai, "AI module installed. Please run migrations and configure your API keys."
  say_status :synth_ai, "Run 'rails db:seed' to create example prompt templates and AI jobs."
end
