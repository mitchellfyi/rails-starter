# frozen_string_literal: true

class AiProviderTestService
  attr_reader :provider

  def initialize(provider)
    @provider = provider
  end

  def test_connection(api_key = nil)
    case provider.slug
    when 'openai'
      test_openai_connection(api_key)
    when 'anthropic'
      test_anthropic_connection(api_key)
    when 'cohere'
      test_cohere_connection(api_key)
    else
      { success: false, error: "Unknown provider: #{provider.slug}" }
    end
  end

  def test_credential(credential)
    start_time = Time.current
    api_key = credential.api_key_decrypted
    
    result = test_connection(api_key)
    response_time = Time.current - start_time
    
    result.merge(response_time: response_time.round(3))
  end

  private

  def test_openai_connection(api_key)
    return { success: false, error: "API key required" } unless api_key

    begin
      require 'openai'
      
      client = OpenAI::Client.new(access_token: api_key)
      
      # Simple test request
      response = client.models
      
      if response['data'] && response['data'].any?
        { success: true, message: "Connection successful", models_count: response['data'].size }
      else
        { success: false, error: "No models available" }
      end
    rescue => e
      { success: false, error: "Connection failed: #{e.message}" }
    end
  end

  def test_anthropic_connection(api_key)
    return { success: false, error: "API key required" } unless api_key

    begin
      # Mock test for Anthropic - replace with actual implementation
      { success: true, message: "Anthropic connection test (mock)" }
    rescue => e
      { success: false, error: "Connection failed: #{e.message}" }
    end
  end

  def test_cohere_connection(api_key)
    return { success: false, error: "API key required" } unless api_key

    begin
      # Mock test for Cohere - replace with actual implementation
      { success: true, message: "Cohere connection test (mock)" }
    rescue => e
      { success: false, error: "Connection failed: #{e.message}" }
    end
  end
end