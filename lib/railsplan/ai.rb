# frozen_string_literal: true

require "railsplan/ai_config"
require "railsplan/ai_provider/base"
require "railsplan/ai_provider/openai"
require "railsplan/ai_provider/claude"
require "railsplan/ai_provider/gemini"
require "railsplan/ai_provider/cursor"

module RailsPlan
  # Unified AI interface for multiple providers
  module AI
    class << self
      # Main entry point for AI calls across all providers
      # 
      # @param provider [Symbol] AI provider (:openai, :claude, :gemini, :cursor)
      # @param prompt [String] The prompt to send to the AI
      # @param context [Hash] Additional context for the prompt
      # @param format [Symbol] Expected output format (:markdown, :ruby, :json, :html_partial)
      # @param options [Hash] Additional options (model, temperature, max_tokens, etc.)
      # @return [Hash] { output: String, metadata: Hash }
      def call(provider:, prompt:, context: {}, format: :markdown, **options)
        validate_inputs!(provider, prompt, format)
        
        # Load configuration for the provider
        ai_config = RailsPlan::AIConfig.new(provider: provider)
        
        unless ai_config.configured?
          raise RailsPlan::Error, "AI provider #{provider} is not configured"
        end
        
        # Get the appropriate provider instance
        provider_instance = get_provider(provider, ai_config)
        
        # Prepare the call metadata
        call_metadata = {
          provider: provider,
          model: ai_config.model,
          format: format,
          timestamp: Time.now.iso8601,
          context_size: context.to_s.length,
          prompt_size: prompt.length
        }
        
        begin
          # Make the call with retry logic
          result = with_retry(provider, 3) do
            provider_instance.call(prompt, context, format, options)
          end
          
          # Validate the output format
          validated_output = validate_output(result[:output], format)
          
          # Merge metadata
          final_metadata = call_metadata.merge(result[:metadata] || {})
          final_metadata[:success] = true
          
          # Log the interaction
          log_interaction(prompt, validated_output, final_metadata)
          log_usage(final_metadata)
          
          {
            output: validated_output,
            metadata: final_metadata
          }
          
        rescue => error
          # Log the error
          error_metadata = call_metadata.merge(
            success: false,
            error: error.message,
            error_class: error.class.name
          )
          
          log_interaction(prompt, nil, error_metadata)
          
          # Try fallback provider if available
          if options[:allow_fallback] && (fallback_provider = get_fallback_provider(provider))
            RailsPlan.logger.warn("Primary provider #{provider} failed, trying fallback #{fallback_provider}")
            return call(
              provider: fallback_provider,
              prompt: prompt,
              context: context,
              format: format,
              allow_fallback: false, # Prevent infinite fallback loops
              **options.except(:allow_fallback)
            )
          end
          
          raise RailsPlan::Error, "AI call failed: #{error.message}"
        end
      end
      
      # List available providers
      def available_providers
        [:openai, :claude, :gemini, :cursor]
      end
      
      # Check if a provider is available and configured
      def provider_available?(provider)
        return false unless available_providers.include?(provider)
        
        begin
          ai_config = RailsPlan::AIConfig.new(provider: provider)
          ai_config.configured?
        rescue
          false
        end
      end
      
      # Get the default provider based on configuration
      def default_provider
        config = RailsPlan::AIConfig.new
        config.provider.to_sym
      end
      
      private
      
      def validate_inputs!(provider, prompt, format)
        unless available_providers.include?(provider)
          raise ArgumentError, "Unsupported provider: #{provider}. Available: #{available_providers.join(', ')}"
        end
        
        if prompt.nil? || prompt.strip.empty?
          raise ArgumentError, "Prompt cannot be nil or empty"
        end
        
        valid_formats = [:markdown, :ruby, :json, :html_partial]
        unless valid_formats.include?(format)
          raise ArgumentError, "Unsupported format: #{format}. Available: #{valid_formats.join(', ')}"
        end
      end
      
      def get_provider(provider, ai_config)
        case provider
        when :openai
          RailsPlan::AIProvider::OpenAI.new(ai_config)
        when :claude
          RailsPlan::AIProvider::Claude.new(ai_config)
        when :gemini
          RailsPlan::AIProvider::Gemini.new(ai_config)
        when :cursor
          RailsPlan::AIProvider::Cursor.new(ai_config)
        else
          raise RailsPlan::Error, "Unknown provider: #{provider}"
        end
      end
      
      def with_retry(provider, max_retries)
        retries = 0
        begin
          yield
        rescue RailsPlan::Error => e
          retries += 1
          if retries <= max_retries
            delay = 2 ** retries # Exponential backoff
            RailsPlan.logger.warn("Provider #{provider} failed (attempt #{retries}), retrying in #{delay}s: #{e.message}")
            sleep(delay)
            retry
          else
            raise
          end
        end
      end
      
      def validate_output(output, format)
        case format
        when :json
          # Validate JSON format
          begin
            JSON.parse(output)
            output
          rescue JSON::ParserError
            raise RailsPlan::Error, "AI output is not valid JSON"
          end
        when :ruby
          # Basic Ruby syntax validation
          begin
            RubyVM::InstructionSequence.compile(output)
            output
          rescue SyntaxError => e
            raise RailsPlan::Error, "AI output is not valid Ruby: #{e.message}"
          end
        else
          # For markdown and html_partial, just return as-is
          output
        end
      end
      
      def get_fallback_provider(failed_provider)
        fallback_order = {
          openai: :claude,
          claude: :openai,
          gemini: :openai,
          cursor: :openai
        }
        
        fallback = fallback_order[failed_provider]
        return nil unless fallback
        
        # Only use fallback if it's configured
        provider_available?(fallback) ? fallback : nil
      end
      
      def log_interaction(prompt, output, metadata)
        log_dir = File.expand_path(".railsplan")
        log_file = File.join(log_dir, "prompts.log")
        
        # Ensure log directory exists
        FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
        
        log_entry = {
          timestamp: metadata[:timestamp],
          provider: metadata[:provider],
          model: metadata[:model],
          format: metadata[:format],
          success: metadata[:success],
          prompt_size: metadata[:prompt_size],
          prompt: prompt,
          output: output,
          metadata: metadata
        }
        
        # Append to log file
        File.open(log_file, "a") do |f|
          f.puts JSON.generate(log_entry)
        end
      rescue => e
        RailsPlan.logger.error("Failed to log AI interaction: #{e.message}")
      end
      
      def log_usage(metadata)
        log_dir = File.expand_path(".railsplan")
        log_file = File.join(log_dir, "ai_usage.log")
        
        # Ensure log directory exists
        FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
        
        usage_entry = {
          timestamp: metadata[:timestamp],
          provider: metadata[:provider],
          model: metadata[:model],
          tokens_used: metadata[:tokens_used] || 0,
          cost_estimate: metadata[:cost_estimate] || 0.0,
          success: metadata[:success]
        }
        
        # Append to log file
        File.open(log_file, "a") do |f|
          f.puts JSON.generate(usage_entry)
        end
      rescue => e
        RailsPlan.logger.error("Failed to log AI usage: #{e.message}")
      end
    end
  end
end