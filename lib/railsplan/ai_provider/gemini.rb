# frozen_string_literal: true

require "railsplan/ai_provider/base"
require "net/http"
require "json"
require "uri"

module RailsPlan
  module AIProvider
    # Google Gemini provider implementation
    class Gemini < Base
      PRICING = {
        "gemini-1.5-pro" => { input: 0.0035, output: 0.0105 }, # Per 1k tokens
        "gemini-1.5-flash" => { input: 0.00035, output: 0.00105 },
        "gemini-pro" => { input: 0.0005, output: 0.0015 }
      }.freeze
      
      API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
      
      def call(prompt, context, format, options = {})
        full_prompt = build_full_prompt(prompt, context, format)
        
        begin
          # Prepare request body
          request_body = {
            contents: [
              {
                parts: [
                  { text: full_prompt }
                ]
              }
            ],
            generationConfig: {
              temperature: options[:temperature] || (options[:creative] ? 0.7 : 0.1),
              maxOutputTokens: options[:max_tokens] || 4000
            }
          }
          
          # Add response format hints for JSON
          if format == :json
            request_body[:generationConfig][:responseMimeType] = "application/json"
          end
          
          # Make API call
          response = make_api_request(request_body)
          
          # Extract content
          content = response.dig("candidates", 0, "content", "parts", 0, "text")
          unless content
            raise RailsPlan::Error, "No content in Gemini response"
          end
          
          # Extract usage information (Gemini may not always provide this)
          usage = response.dig("usageMetadata") || {}
          prompt_tokens = usage["promptTokenCount"] || 0
          completion_tokens = usage["candidatesTokenCount"] || 0
          total_tokens = usage["totalTokenCount"] || (prompt_tokens + completion_tokens)
          
          # Calculate cost
          cost = calculate_cost(prompt_tokens, completion_tokens)
          
          metadata = {
            model: @ai_config.model,
            prompt_tokens: prompt_tokens,
            completion_tokens: completion_tokens,
            total_tokens: total_tokens,
            tokens_used: total_tokens,
            cost_estimate: cost,
            finish_reason: response.dig("candidates", 0, "finishReason")
          }
          
          validate_response({
            output: content,
            metadata: metadata
          })
          
        rescue => error
          handle_api_error(error)
        end
      end
      
      # Override client method since we're not using a gem
      def client
        @ai_config.api_key
      end
      
      private
      
      def make_api_request(request_body)
        model_name = @ai_config.model || "gemini-1.5-pro"
        uri = URI("#{API_BASE_URL}/models/#{model_name}:generateContent?key=#{@ai_config.api_key}")
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(request_body)
        
        response = http.request(request)
        
        unless response.is_a?(Net::HTTPSuccess)
          error_message = "Gemini API error: #{response.code} #{response.message}"
          if response.body
            begin
              error_body = JSON.parse(response.body)
              error_message += " - #{error_body.dig("error", "message")}"
            rescue JSON::ParserError
              error_message += " - #{response.body}"
            end
          end
          raise RailsPlan::Error, error_message
        end
        
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise RailsPlan::Error, "Invalid JSON response from Gemini: #{e.message}"
      end
      
      def calculate_cost(prompt_tokens, completion_tokens)
        pricing = PRICING[@ai_config.model] || PRICING["gemini-1.5-pro"]
        
        input_cost = (prompt_tokens / 1000.0) * pricing[:input]
        output_cost = (completion_tokens / 1000.0) * pricing[:output]
        
        input_cost + output_cost
      end
      
      def extract_token_usage(response_metadata)
        response_metadata.dig("usageMetadata", "totalTokenCount") || 0
      end
    end
  end
end