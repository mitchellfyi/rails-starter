# frozen_string_literal: true

# Service for testing AI provider connectivity and model validation
class AiProviderTestService
  attr_reader :ai_credential, :ai_provider
  
  def initialize(ai_credential)
    @ai_credential = ai_credential
    @ai_provider = ai_credential.ai_provider
  end
  
  # Perform comprehensive connectivity test
  def test_connection
    result = {
      credential_id: ai_credential.id,
      provider: ai_provider.slug,
      started_at: Time.current
    }
    
    begin
      # Basic connectivity test
      basic_test = ai_provider.test_connectivity(ai_credential.api_key)
      result.merge!(basic_test)
      
      if basic_test[:success]
        # Test the specific model if basic connection works
        model_test = test_model_access
        result[:model_test] = model_test
        
        # Test a simple prompt if model works
        if model_test[:success]
          prompt_test = test_simple_prompt
          result[:prompt_test] = prompt_test
          result[:success] = prompt_test[:success]
        end
      end
      
    rescue => e
      result.merge!(
        success: false,
        error: e.message,
        error_class: e.class.name
      )
    ensure
      result[:completed_at] = Time.current
      result[:duration] = result[:completed_at] - result[:started_at]
    end
    
    # Store the test result
    ai_credential.update!(
      last_tested_at: result[:completed_at],
      last_test_result: result.to_json
    )
    
    result
  end
  
  # Test if the specific model is accessible
  def test_model_access
    case ai_provider.slug
    when 'openai'
      test_openai_model
    when 'anthropic'
      test_anthropic_model
    when 'cohere'
      test_cohere_model
    else
      { success: false, error: "Model testing not implemented for #{ai_provider.slug}" }
    end
  end
  
  # Test with a simple prompt to verify end-to-end functionality
  def test_simple_prompt
    test_prompt = "Hello, this is a connectivity test. Please respond with 'Connection successful.'"
    
    begin
      runner = ai_credential.create_job_runner
      result = runner.test_prompt(test_prompt)
      
      if result.is_a?(Hash) && result[:error]
        result
      else
        { success: true, message: "Prompt test successful", response_preview: truncate_response(result) }
      end
    rescue => e
      { success: false, error: "Prompt test failed: #{e.message}", error_class: e.class.name }
    end
  end
  
  # Get test history for the credential
  def test_history
    return [] unless ai_credential.last_test_result.present?
    
    begin
      [JSON.parse(ai_credential.last_test_result)]
    rescue JSON::ParserError
      []
    end
  end
  
  # Check if credential passed its last test
  def last_test_successful?
    return false unless ai_credential.last_test_result.present?
    
    begin
      result = JSON.parse(ai_credential.last_test_result)
      result['success'] == true
    rescue JSON::ParserError
      false
    end
  end
  
  private
  
  def test_openai_model
    client = create_openai_client
    
    # Try to make a minimal completion request
    response = client.chat(
      parameters: {
        model: ai_credential.preferred_model,
        messages: [{ role: "user", content: "Test" }],
        max_tokens: 1,
        temperature: 0
      }
    )
    
    if response.dig("choices", 0, "message", "content")
      { success: true, message: "Model #{ai_credential.preferred_model} is accessible" }
    else
      { success: false, error: "Model response was empty or invalid" }
    end
  rescue => e
    { success: false, error: "Model test failed: #{e.message}", error_class: e.class.name }
  end
  
  def test_anthropic_model
    # Placeholder for Anthropic model testing
    # In a real implementation, this would test the specific Claude model
    { success: true, message: "Anthropic model test (placeholder)" }
  end
  
  def test_cohere_model
    # Placeholder for Cohere model testing
    # In a real implementation, this would test the specific Command model
    { success: true, message: "Cohere model test (placeholder)" }
  end
  
  def create_openai_client
    require 'openai'
    OpenAI::Client.new(
      access_token: ai_credential.api_key,
      uri_base: ai_provider.api_base_url
    )
  end
  
  def truncate_response(response, limit = 100)
    if response.is_a?(String)
      response.length > limit ? "#{response[0..limit]}..." : response
    elsif response.respond_to?(:to_s)
      str = response.to_s
      str.length > limit ? "#{str[0..limit]}..." : str
    else
      "[Non-string response]"
    end
  end
end