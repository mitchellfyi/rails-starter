# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script adds AI/LLM capabilities including prompt templates,
# asynchronous job processing, and multi-context providers.

say_status :ai, "Installing AI module with prompt templates and LLM jobs"

# Add AI specific gems to the application's Gemfile
add_gem 'ruby-openai', '~> 7.0'
add_gem 'anthropic', '~> 0.1'
add_gem 'tiktoken_ruby', '~> 0.0.7'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create an initializer for AI configuration
  initializer 'ai.rb', <<~'RUBY'
    # AI module configuration
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4o-mini'
    Rails.application.config.ai.temperature = 0.7
    Rails.application.config.ai.max_tokens = 1000
    Rails.application.config.ai.timeout = 30

    # Configure API clients
    Rails.application.config.ai.openai_api_key = Rails.application.credentials.openai&.api_key
    Rails.application.config.ai.anthropic_api_key = Rails.application.credentials.anthropic&.api_key
  RUBY

  # Generate models and migrations
  generate 'model', 'PromptTemplate', 'name:string', 'content:text', 'description:text', 'tags:string', 'version:integer', 'output_format:string', 'active:boolean'
  generate 'model', 'LlmOutput', 'prompt_template:references', 'input_data:json', 'output_content:text', 'model_used:string', 'tokens_used:integer', 'processing_time:float', 'status:string', 'error_message:text'
  generate 'model', 'LlmJob', 'prompt_template:references', 'context_data:json', 'status:string', 'priority:integer', 'scheduled_at:datetime', 'completed_at:datetime'

  # Generate controllers
  generate 'controller', 'PromptTemplates', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy'
  generate 'controller', 'LlmJobs', 'index', 'show', 'create', 'retry'

  # Create AI job processor
  create_file 'app/jobs/llm_processing_job.rb', <<~'RUBY'
    class LlmProcessingJob < ApplicationJob
      queue_as :default
      
      def perform(llm_job_id, prompt_template_id, context_data = {})
        llm_job = LlmJob.find(llm_job_id)
        prompt_template = PromptTemplate.find(prompt_template_id)
        
        llm_job.update!(status: 'processing')
        
        begin
          processor = LlmProcessor.new(prompt_template, context_data)
          result = processor.execute
          
          llm_output = LlmOutput.create!(
            prompt_template: prompt_template,
            input_data: context_data,
            output_content: result[:content],
            model_used: result[:model],
            tokens_used: result[:tokens],
            processing_time: result[:processing_time],
            status: 'completed'
          )
          
          llm_job.update!(
            status: 'completed',
            completed_at: Time.current
          )
          
        rescue => e
          llm_job.update!(status: 'failed')
          LlmOutput.create!(
            prompt_template: prompt_template,
            input_data: context_data,
            status: 'failed',
            error_message: e.message
          )
          raise e
        end
      end
    end
  RUBY

  # Create LLM processor service
  create_file 'app/services/llm_processor.rb', <<~'RUBY'
    class LlmProcessor
      attr_reader :prompt_template, :context_data

      def initialize(prompt_template, context_data = {})
        @prompt_template = prompt_template
        @context_data = context_data
      end

      def execute
        start_time = Time.current
        
        # Interpolate template with context data
        rendered_prompt = interpolate_template(prompt_template.content, context_data)
        
        # Choose client based on model
        result = if prompt_template.model_used&.start_with?('gpt')
          execute_openai(rendered_prompt)
        elsif prompt_template.model_used&.start_with?('claude')
          execute_anthropic(rendered_prompt)
        else
          execute_openai(rendered_prompt) # Default to OpenAI
        end
        
        processing_time = Time.current - start_time
        
        {
          content: result[:content],
          model: result[:model],
          tokens: result[:tokens],
          processing_time: processing_time
        }
      end

      private

      def interpolate_template(template, data)
        template.gsub(/\{\{(\w+)\}\}/) do |match|
          key = $1.to_sym
          data[key] || data[key.to_s] || match
        end
      end

      def execute_openai(prompt)
        client = OpenAI::Client.new(access_token: Rails.application.config.ai.openai_api_key)
        
        response = client.chat(
          parameters: {
            model: Rails.application.config.ai.default_model,
            messages: [{ role: 'user', content: prompt }],
            temperature: Rails.application.config.ai.temperature,
            max_tokens: Rails.application.config.ai.max_tokens
          }
        )
        
        {
          content: response.dig('choices', 0, 'message', 'content'),
          model: response['model'],
          tokens: response.dig('usage', 'total_tokens')
        }
      end

      def execute_anthropic(prompt)
        # Placeholder for Anthropic implementation
        {
          content: "Anthropic response placeholder",
          model: "claude-3-sonnet",
          tokens: 100
        }
      end
    end
  RUBY

  say_status :ai, "AI module installed. Don't forget to:"
  say_status :ai, "1. Run rails db:migrate"
  say_status :ai, "2. Configure API keys in Rails credentials"
  say_status :ai, "3. Add routes for AI controllers"
  say_status :ai, "4. Run the seeds to create sample prompt templates"
end
