# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI module.

say_status :synth_ai, "Installing AI module"

# Add AI specific gems to the application's Gemfile
add_gem 'ruby-openai', '~> 7.0'
add_gem 'paper_trail'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create domain-specific directories
  run 'mkdir -p app/domains/ai/app/{controllers,services,jobs,views,policies,queries}'
  run 'mkdir -p app/models' # Ensure models directory exists
  run 'mkdir -p spec/domains/ai/{models,controllers,jobs,fixtures}'
  # Create an initializer for AI configuration
  initializer 'ai.rb', <<~'RUBY'
    # AI module configuration
    # Set your default model and any other AI related settings here
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4'
    Rails.application.config.ai.default_temperature = 0.7
    Rails.application.config.ai.max_tokens = 4096
    
    # Supported output formats for prompt templates
    Rails.application.config.ai.output_formats = %w[json markdown html_partial text].freeze
  RUBY

  # Set up PaperTrail for versioning
  initializer 'paper_trail.rb', <<~'RUBY'
    PaperTrail.config.track_associations = false
    PaperTrail.config.association_reify_error_behaviour = :warn
  RUBY

  # Copy PromptTemplate model with versioning support
  copy_file File.join(__dir__, 'app/models/prompt_template.rb'), 'app/models/prompt_template.rb'
  copy_file File.join(__dir__, 'app/models/prompt_execution.rb'), 'app/models/prompt_execution.rb'
      has_many :prompt_executions, dependent: :destroy

      before_validation :generate_slug, if: -> { slug.blank? && name.present? }

      scope :by_tag, ->(tag) { where('? = ANY(tags)', tag) }
      scope :by_output_format, ->(format) { where(output_format: format) }

      # Extract variable names from prompt body (e.g., {{user_name}}, {{company}})
      def variable_names
        prompt_body.scan(/\{\{(\w+)\}\}/).flatten.uniq
      end

      # Render the prompt with provided context variables
      def render_with_context(context = {})
        rendered = prompt_body.dup
        
        variable_names.each do |var_name|
          value = context[var_name] || context[var_name.to_sym] || ""
          rendered.gsub!("{{#{var_name}}}", value.to_s)
        end
        
        rendered
      end

      # Validate that all required variables are present in context
      def validate_context(context)
        missing_vars = variable_names - context.keys.map(&:to_s) - context.keys.map(&:to_sym).map(&:to_s)
        missing_vars.empty? ? true : missing_vars
      end

      # Generate a preview with sample context
      def preview_with_sample_context
        sample_context = variable_names.map { |var| [var, "[#{var}_value]"] }.to_h
        render_with_context(sample_context)
      end

      private

      def generate_slug
        self.slug = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
      end
    end
  RUBY

  # Create PromptExecution model for audit history
  create_file 'app/models/prompt_execution.rb', <<~'RUBY'
    # frozen_string_literal: true

    class PromptExecution < ApplicationRecord
      belongs_to :prompt_template
      belongs_to :user, optional: true
      belongs_to :workspace, optional: true

      validates :input_context, presence: true
      validates :rendered_prompt, presence: true
      validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }

      scope :successful, -> { where(status: 'completed') }
      scope :failed, -> { where(status: 'failed') }
      scope :recent, -> { order(created_at: :desc) }

      def success?
        status == 'completed'
      end

      def failed?
        status == 'failed'
      end

      def duration
        return nil unless started_at && completed_at
        completed_at - started_at
      end
    end
  RUBY

  # Copy enhanced migrations with versioning support
  copy_file File.join(__dir__, 'db/migrate/002_create_prompt_templates.rb'), 'db/migrate/002_create_prompt_templates.rb'
  copy_file File.join(__dir__, 'db/migrate/003_create_prompt_executions.rb'), 'db/migrate/003_create_prompt_executions.rb'
  copy_file File.join(__dir__, 'db/migrate/004_create_versions.rb'), 'db/migrate/004_create_versions.rb'
  copy_file File.join(__dir__, 'db/migrate/005_add_prompt_execution_to_llm_outputs.rb'), 'db/migrate/005_add_prompt_execution_to_llm_outputs.rb'

  # Copy enhanced controllers with versioning and preview support
  copy_file File.join(__dir__, 'app/controllers/prompt_templates_controller.rb'), 'app/controllers/prompt_templates_controller.rb'
  copy_file File.join(__dir__, 'app/controllers/prompt_executions_controller.rb'), 'app/controllers/prompt_executions_controller.rb'

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
