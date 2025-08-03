# frozen_string_literal: true

require "railsplan/ai_provider/base"

module RailsPlan
  module AIProvider
    # Claude (Anthropic) provider implementation
    class Claude < Base
      PRICING = {
        "claude-3-5-sonnet-20241022" => { input: 0.003, output: 0.015 }, # Per 1k tokens
        "claude-3-5-haiku-20241022" => { input: 0.001, output: 0.005 },
        "claude-3-opus-20240229" => { input: 0.015, output: 0.075 },
        "claude-3-sonnet-20240229" => { input: 0.003, output: 0.015 }
      }.freeze
      
      def call(prompt, context, format, options = {})
        full_prompt = build_full_prompt(prompt, context, format)
        
        begin
          # Prepare request parameters
          params = {
            model: @ai_config.model,
            max_tokens: options[:max_tokens] || 4000,
            temperature: options[:temperature] || (options[:creative] ? 0.7 : 0.1),
            messages: [
              { role: "user", content: full_prompt }
            ]
          }
          
          # Add system message for JSON format if requested
          if format == :json
            params[:system] = "You are a helpful assistant that responds only with valid JSON. Do not include any text outside of the JSON response."
          end
          
          # Make API call
          response = client.messages(**params)
          
          # Extract content
          content = response.dig("content", 0, "text")
          unless content
            raise RailsPlan::Error, "No content in Claude response"
          end
          
          # Extract usage information
          usage = response["usage"] || {}
          input_tokens = usage["input_tokens"] || 0
          output_tokens = usage["output_tokens"] || 0
          total_tokens = input_tokens + output_tokens
          
          # Calculate cost
          cost = calculate_cost(input_tokens, output_tokens)
          
          metadata = {
            model: @ai_config.model,
            input_tokens: input_tokens,
            output_tokens: output_tokens,
            total_tokens: total_tokens,
            tokens_used: total_tokens,
            cost_estimate: cost,
            stop_reason: response["stop_reason"]
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
      
      def calculate_cost(input_tokens, output_tokens)
        pricing = PRICING[@ai_config.model] || PRICING["claude-3-sonnet-20240229"]
        
        input_cost = (input_tokens / 1000.0) * pricing[:input]
        output_cost = (output_tokens / 1000.0) * pricing[:output]
        
        input_cost + output_cost
      end
      
      def extract_token_usage(response_metadata)
        (response_metadata["input_tokens"] || 0) + (response_metadata["output_tokens"] || 0)
      end
    end
  end
end