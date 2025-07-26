# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI module.

say_status :synth_ai, "Installing AI module with PromptTemplate versioning"

# Add AI specific gems to the application's Gemfile
add_gem 'ruby-openai', '~> 7.0'
add_gem 'paper_trail'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create domain-specific directories
  run 'mkdir -p app/controllers app/models app/views'
  run 'mkdir -p test/models test/controllers'
  
  # Create an initializer for AI configuration
  initializer 'ai.rb', <<~'RUBY'
    # AI module configuration
    # Set your default model and any other AI related settings here
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4'
    Rails.application.config.ai.default_temperature = 0.7
    Rails.application.config.ai.max_tokens = 4096
    
    # Supported output formats for prompt templates
    Rails.application.config.ai.output_formats = %w[text json markdown html].freeze
  RUBY

  # Set up PaperTrail for versioning
  initializer 'paper_trail.rb', <<~'RUBY'
    PaperTrail.config.track_associations = false
    PaperTrail.config.association_reify_error_behaviour = :warn
  RUBY

  # Copy PromptTemplate model with versioning support
  copy_file File.join(__dir__, 'app/models/prompt_template.rb'), 'app/models/prompt_template.rb'
  copy_file File.join(__dir__, 'app/models/prompt_execution.rb'), 'app/models/prompt_execution.rb'

  # Update LLMOutput model to integrate with PromptTemplate
  gsub_file 'app/models/llm_output.rb', 
    /belongs_to :agent, optional: true/,
    'belongs_to :agent, optional: true
  belongs_to :prompt_template, foreign_key: :template_name, primary_key: :slug, optional: true
  belongs_to :prompt_execution, optional: true' do
    say_status :synth_ai, "Updated LLMOutput model for PromptTemplate integration"
  end

  # Copy enhanced migrations with versioning support
  copy_file File.join(__dir__, 'db/migrate/002_create_prompt_templates.rb'), 'db/migrate/002_create_prompt_templates.rb'
  copy_file File.join(__dir__, 'db/migrate/003_create_prompt_executions.rb'), 'db/migrate/003_create_prompt_executions.rb'
  copy_file File.join(__dir__, 'db/migrate/004_create_versions.rb'), 'db/migrate/004_create_versions.rb'
  copy_file File.join(__dir__, 'db/migrate/005_add_prompt_execution_to_llm_outputs.rb'), 'db/migrate/005_add_prompt_execution_to_llm_outputs.rb'

  # Copy enhanced controllers with versioning and preview support
  copy_file File.join(__dir__, 'app/controllers/prompt_templates_controller.rb'), 'app/controllers/prompt_templates_controller.rb'
  copy_file File.join(__dir__, 'app/controllers/prompt_executions_controller.rb'), 'app/controllers/prompt_executions_controller.rb'

  # Update routes to include PromptTemplate routes
  route <<~'RUBY'
    # PromptTemplate management routes with versioning
    resources :prompt_templates do
      member do
        post :preview
        get :diff
        post :publish
        post :create_version
      end
      resources :prompt_executions, only: [:index, :show, :create, :destroy]
    end
  RUBY

  # Copy enhanced views with versioning and preview support
  run 'mkdir -p app/views/prompt_templates'
  copy_file File.join(__dir__, 'app/views/prompt_templates/index.html.erb'), 'app/views/prompt_templates/index.html.erb'
  copy_file File.join(__dir__, 'app/views/prompt_templates/show.html.erb'), 'app/views/prompt_templates/show.html.erb'
  copy_file File.join(__dir__, 'app/views/prompt_templates/new.html.erb'), 'app/views/prompt_templates/new.html.erb'
  copy_file File.join(__dir__, 'app/views/prompt_templates/edit.html.erb'), 'app/views/prompt_templates/edit.html.erb'
  copy_file File.join(__dir__, 'app/views/prompt_templates/_form.html.erb'), 'app/views/prompt_templates/_form.html.erb'

  # Copy seed data with example templates
  copy_file File.join(__dir__, 'db/seeds/prompt_templates.rb'), 'db/seeds/prompt_templates.rb'

  # Copy test files
  copy_file File.join(__dir__, 'test/models/prompt_template_test.rb'), 'test/models/prompt_template_test.rb'
  copy_file File.join(__dir__, 'test/models/prompt_execution_test.rb'), 'test/models/prompt_execution_test.rb'

  # Update the main seeds file to include prompt template seeds
  append_to_file 'db/seeds.rb', <<~'RUBY'
    
    # Load AI module seeds
    load Rails.root.join('db', 'seeds', 'prompt_templates.rb') if File.exist?(Rails.root.join('db', 'seeds', 'prompt_templates.rb'))
  RUBY

  say_status :synth_ai, "PromptTemplate versioning and preview system installed successfully!"
  say_status :synth_ai, ""
  say_status :synth_ai, "Next steps after installation:"
  say_status :synth_ai, "1. Run 'rails db:migrate' to create database tables"
  say_status :synth_ai, "2. Run 'rails db:seed' to create example templates"
  say_status :synth_ai, "3. Visit /prompt_templates to start using the interface"
  say_status :synth_ai, "4. Run 'rails test' to verify everything works"
end