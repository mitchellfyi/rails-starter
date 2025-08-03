# frozen_string_literal: true

module RailsPlan
  module AIProvider
    # Base class for all AI providers
    class Base
      attr_reader :ai_config
      
      def initialize(ai_config)
        @ai_config = ai_config
      end
      
      # Abstract method that all providers must implement
      # @param prompt [String] The prompt to send
      # @param context [Hash] Additional context
      # @param format [Symbol] Expected output format
      # @param options [Hash] Provider-specific options
      # @return [Hash] { output: String, metadata: Hash }
      def call(prompt, context, format, options = {})
        raise NotImplementedError, "Subclasses must implement #call"
      end
      
      # Check if the provider is properly configured
      def configured?
        @ai_config.configured?
      end
      
      # Get the client for this provider
      def client
        @ai_config.client
      end
      
      protected
      
      # Build a comprehensive prompt with context
      def build_full_prompt(prompt, context, format)
        parts = []
        
        # Add context if provided
        if context && !context.empty?
          parts << "## Context"
          parts << format_context(context)
          parts << ""
        end
        
        # Add the main prompt
        parts << "## Request"
        parts << prompt
        parts << ""
        
        # Add format-specific instructions
        parts << "## Output Format"
        parts << format_instructions(format)
        
        parts.join("\n")
      end
      
      # Format context hash into readable text
      def format_context(context)
        return "" if context.empty?
        
        formatted = []
        
        context.each do |key, value|
          case key.to_s
          when "app_name"
            formatted << "Application: #{value}"
          when "models"
            if value.is_a?(Array) && !value.empty?
              formatted << "Models: #{value.map { |m| m["class_name"] || m }.join(", ")}"
            end
          when "schema"
            if value.is_a?(Hash) && !value.empty?
              formatted << "Database tables: #{value.keys.join(", ")}"
            end
          when "routes"
            if value.is_a?(Array) && !value.empty?
              formatted << "Routes: #{value.size} endpoints defined"
            end
          when "current_directory"
            formatted << "Working directory: #{value}"
          when "files"
            if value.is_a?(Array) && !value.empty?
              formatted << "Relevant files: #{value.join(", ")}"
            end
          else
            formatted << "#{key.to_s.humanize}: #{value}"
          end
        end
        
        formatted.join("\n")
      end
      
      # Get format-specific instructions
      def format_instructions(format)
        case format
        when :json
          "Please respond with valid JSON only. Do not include any markdown formatting or explanations outside the JSON."
        when :ruby
          "Please respond with valid Ruby code only. Ensure proper syntax and formatting."
        when :markdown
          "Please respond with well-formatted Markdown. Use appropriate headers, lists, and code blocks."
        when :html_partial
          "Please respond with valid HTML partial content. Do not include <html>, <head>, or <body> tags."
        else
          "Please respond in plain text format."
        end
      end
      
      # Extract tokens used from response metadata (provider-specific)
      def extract_token_usage(response_metadata)
        0 # Override in subclasses
      end
      
      # Estimate cost based on tokens and provider pricing (provider-specific)
      def estimate_cost(tokens)
        0.0 # Override in subclasses
      end
      
      # Common error handling for API responses
      def handle_api_error(error)
        case error
        when Net::TimeoutError, Timeout::Error
          raise RailsPlan::Error, "Request timeout - AI provider took too long to respond"
        when Net::HTTPClientError
          raise RailsPlan::Error, "Client error - check API credentials and request format"
        when Net::HTTPServerError
          raise RailsPlan::Error, "Server error - AI provider is experiencing issues"
        when JSON::ParserError
          raise RailsPlan::Error, "Invalid response format from AI provider"
        else
          raise RailsPlan::Error, "Unexpected error: #{error.message}"
        end
      end
      
      # Validate response structure
      def validate_response(response)
        unless response.is_a?(Hash)
          raise RailsPlan::Error, "Provider response must be a hash"
        end
        
        unless response.key?(:output)
          raise RailsPlan::Error, "Provider response missing :output key"
        end
        
        response
      end
    end
  end
end