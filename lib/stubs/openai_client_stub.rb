# frozen_string_literal: true

require 'digest'
require 'json'

module Stubs
  # Stub client for OpenAI API calls in test environment
  # Returns deterministic, predictable responses for testing
  class OpenAIClientStub
    def initialize(api_key: nil)
      @api_key = api_key
    end

    # Completions API stub
    def completions(parameters = {})
      model = parameters[:model] || 'gpt-3.5-turbo'
      messages = parameters[:messages] || []
      max_tokens = parameters[:max_tokens] || 100
      temperature = parameters[:temperature] || 1.0

      # Extract user message for deterministic response generation
      user_message = extract_user_message(messages)
      response_text = generate_deterministic_response(user_message, model)

      {
        'id' => 'chatcmpl-stub123',
        'object' => 'chat.completion',
        'created' => Time.now.to_i,
        'model' => model,
        'choices' => [
          {
            'index' => 0,
            'message' => {
              'role' => 'assistant',
              'content' => response_text
            },
            'finish_reason' => 'stop'
          }
        ],
        'usage' => {
          'prompt_tokens' => estimate_tokens(messages.to_s),
          'completion_tokens' => estimate_tokens(response_text),
          'total_tokens' => estimate_tokens(messages.to_s) + estimate_tokens(response_text)
        }
      }
    end

    # Chat completions API stub (alias for completions)
    def chat(parameters = {})
      completions(parameters)
    end

    # Legacy completions API stub
    def text_completions(parameters = {})
      model = parameters[:model] || 'text-davinci-003'
      prompt = parameters[:prompt] || ''
      max_tokens = parameters[:max_tokens] || 100

      response_text = generate_deterministic_response(prompt, model)

      {
        'id' => 'cmpl-stub123',
        'object' => 'text_completion',
        'created' => Time.now.to_i,
        'model' => model,
        'choices' => [
          {
            'text' => response_text,
            'index' => 0,
            'logprobs' => nil,
            'finish_reason' => 'stop'
          }
        ],
        'usage' => {
          'prompt_tokens' => estimate_tokens(prompt),
          'completion_tokens' => estimate_tokens(response_text),
          'total_tokens' => estimate_tokens(prompt) + estimate_tokens(response_text)
        }
      }
    end

    # Embeddings API stub
    def embeddings(parameters = {})
      input = parameters[:input] || ''
      model = parameters[:model] || 'text-embedding-ada-002'

      # Generate deterministic embeddings based on input hash
      embedding = generate_deterministic_embedding(input)

      {
        'object' => 'list',
        'data' => [
          {
            'object' => 'embedding',
            'embedding' => embedding,
            'index' => 0
          }
        ],
        'model' => model,
        'usage' => {
          'prompt_tokens' => estimate_tokens(input.to_s),
          'total_tokens' => estimate_tokens(input.to_s)
        }
      }
    end

    # Models API stub
    def models
      {
        'object' => 'list',
        'data' => [
          {
            'id' => 'gpt-4',
            'object' => 'model',
            'created' => 1677649963,
            'owned_by' => 'openai',
            'permission' => []
          },
          {
            'id' => 'gpt-3.5-turbo',
            'object' => 'model', 
            'created' => 1677610602,
            'owned_by' => 'openai',
            'permission' => []
          },
          {
            'id' => 'text-embedding-ada-002',
            'object' => 'model',
            'created' => 1671217299,
            'owned_by' => 'openai-internal',
            'permission' => []
          }
        ]
      }
    end

    # Error simulation for testing error handling
    def simulate_error(error_type = :rate_limit)
      case error_type
      when :rate_limit
        raise StandardError, "Rate limit exceeded"
      when :invalid_api_key
        raise StandardError, "Invalid API key provided"
      when :service_unavailable
        raise StandardError, "OpenAI service temporarily unavailable"
      else
        raise StandardError, "Unknown API error"
      end
    end

    private

    # Extract user message from messages array
    def extract_user_message(messages)
      return '' unless messages.is_a?(Array)
      
      user_msg = messages.find { |msg| msg['role'] == 'user' || msg[:role] == 'user' }
      return '' unless user_msg
      
      user_msg['content'] || user_msg[:content] || ''
    end

    # Generate deterministic response based on input
    def generate_deterministic_response(input, model)
      # Create deterministic hash of input for consistent responses
      input_hash = Digest::MD5.hexdigest(input.to_s)[0..6]
      
      # Different responses based on model and input patterns
      if input.to_s.downcase.include?('json')
        %Q({"response": "Deterministic JSON response for test", "hash": "#{input_hash}", "model": "#{model}"})
      elsif input.to_s.downcase.include?('markdown')
        "# Test Response\n\nDeterministic markdown response for testing.\n\nHash: #{input_hash}\nModel: #{model}"
      elsif input.to_s.downcase.include?('code')
        "```ruby\n# Deterministic code response\nclass TestResponse\n  def initialize\n    @hash = '#{input_hash}'\n    @model = '#{model}'\n  end\nend\n```"
      else
        "This is a deterministic test response generated by #{model} with hash #{input_hash}. The response will always be the same for the same input."
      end
    end

    # Generate deterministic embedding vector
    def generate_deterministic_embedding(input)
      # Create deterministic seed from input
      seed = Digest::MD5.hexdigest(input.to_s).to_i(16) % 1000000
      rng = Random.new(seed)
      
      # Generate 1536-dimensional embedding (OpenAI standard)
      Array.new(1536) { rng.rand(-1.0..1.0) }
    end

    # Estimate token count (rough approximation)
    def estimate_tokens(text)
      # Rough estimation: ~4 characters per token
      (text.to_s.length / 4.0).ceil
    end
  end
end