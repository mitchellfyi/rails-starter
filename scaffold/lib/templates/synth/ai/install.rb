# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI module.

say_status :synth_ai, "Installing AI module..."

# Add AI specific gems to the application's Gemfile  
gem 'ruby-openai', '~> 6.3'
gem 'anthropic', '~> 0.3'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Generate models for prompt templates and LLM outputs
  generate :model, 'PromptTemplate', 'name:string', 'description:text', 'content:text', 'version:integer', 'tags:string'
  generate :model, 'LlmOutput', 'prompt_template:references', 'user:references', 'input_data:json', 'output_data:json', 'model:string', 'status:string'
  
  # Generate the LLM job
  generate :job, 'LlmJob'
  
  # Create an initializer for AI configuration
  create_file 'config/initializers/ai.rb', <<~'CONFIG'
    # AI module configuration
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4'
    Rails.application.config.ai.openai_api_key = ENV['OPENAI_API_KEY']
    Rails.application.config.ai.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  CONFIG

  # Create AI service classes
  create_file 'app/services/ai/prompt_service.rb', <<~'SERVICE'
    # frozen_string_literal: true

    module Ai
      class PromptService
        def self.execute(template:, context: {}, model: nil)
          model ||= Rails.application.config.ai.default_model
          
          # TODO: Implement prompt execution with variable interpolation
          content = interpolate_variables(template.content, context)
          
          {
            content: content,
            model: model,
            status: 'success'
          }
        end

        private

        def self.interpolate_variables(content, context)
          context.each do |key, value|
            content = content.gsub("{{#{key}}}", value.to_s)
          end
          content
        end
      end
    end
  SERVICE

  # Create seeds for AI module
  create_file 'db/seeds/ai_seeds.rb', <<~'SEEDS'
    # AI module seeds
    puts "Seeding AI module..."

    PromptTemplate.find_or_create_by(name: 'summarize_text') do |template|
      template.description = 'Summarize the given text'
      template.content = 'Please summarize the following text: {{text}}'
      template.version = 1
      template.tags = 'summarization,text'
    end

    PromptTemplate.find_or_create_by(name: 'generate_title') do |template|
      template.description = 'Generate a title for content'
      template.content = 'Generate a compelling title for: {{content}}'
      template.version = 1
      template.tags = 'generation,title'
    end

    puts "AI module seeded!"
  SEEDS
  
  # Update main seeds file to include AI seeds
  append_to_file 'db/seeds.rb', "\nload Rails.root.join('db', 'seeds', 'ai_seeds.rb') if File.exist?(Rails.root.join('db', 'seeds', 'ai_seeds.rb'))"

  # Run migrations
  rails_command 'db:migrate'
  
  say_status :synth_ai, "AI module installed successfully!"
  say_status :synth_ai, "Run 'rails db:seed' to load example prompt templates"
end
