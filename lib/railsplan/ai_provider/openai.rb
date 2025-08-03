# frozen_string_literal: true

require "railsplan/ai_provider/base"

module RailsPlan
  module AIProvider
    # OpenAI provider implementation
    class OpenAI < Base
      PRICING = {
        "gpt-4o" => { input: 0.005, output: 0.015 }, # Per 1k tokens
        "gpt-4o-mini" => { input: 0.00015, output: 0.0006 },
        "gpt-4" => { input: 0.03, output: 0.06 },
        "gpt-3.5-turbo" => { input: 0.001, output: 0.002 }
      }.freeze
      
      def call(prompt, context, format, options = {})
        full_prompt = build_full_prompt(prompt, context, format)
        
        begin
          # Prepare request parameters
          params = {
            model: @ai_config.model,
            messages: [
              { role: "user", content: full_prompt }
            ],
            temperature: options[:temperature] || (options[:creative] ? 0.7 : 0.1),
            max_tokens: options[:max_tokens] || 4000
          }
          
          # Add response format for JSON if requested
          if format == :json
            params[:response_format] = { type: "json_object" }
          end
          
          # Make API call
          response = client.chat(parameters: params)
          
          # Extract content
          content = response.dig("choices", 0, "message", "content")
          unless content
            raise RailsPlan::Error, "No content in OpenAI response"
          end
          
          # Extract usage information
          usage = response["usage"] || {}
          total_tokens = usage["total_tokens"] || 0
          prompt_tokens = usage["prompt_tokens"] || 0
          completion_tokens = usage["completion_tokens"] || 0
          
          # Calculate cost
          cost = calculate_cost(prompt_tokens, completion_tokens)
          
          metadata = {
            model: @ai_config.model,
            prompt_tokens: prompt_tokens,
            completion_tokens: completion_tokens,
            total_tokens: total_tokens,
            tokens_used: total_tokens,
            cost_estimate: cost,
            finish_reason: response.dig("choices", 0, "finish_reason")
          }
          
          validate_response({
            output: content,
            metadata: metadata
          })
          
        rescue => error
          handle_api_error(error)
        end
      end
      
      private
      
      def calculate_cost(prompt_tokens, completion_tokens)
        pricing = PRICING[@ai_config.model] || PRICING["gpt-4o"]
        
        input_cost = (prompt_tokens / 1000.0) * pricing[:input]
        output_cost = (completion_tokens / 1000.0) * pricing[:output]
        
        input_cost + output_cost
      end
      
      def extract_token_usage(response_metadata)
        response_metadata["usage"]&.dig("total_tokens") || 0
      end
    end
  end
end