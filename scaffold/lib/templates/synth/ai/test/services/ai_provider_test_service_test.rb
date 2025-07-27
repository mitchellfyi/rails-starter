# frozen_string_literal: true

require 'test_helper'

class AiProviderTestServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com", password: "password")
    @workspace = Workspace.create!(
      name: "Test Workspace",
      slug: "test-workspace",
      created_by: @user
    )
    
    @ai_provider = AiProvider.create!(
      name: "OpenAI",
      slug: "openai",
      api_base_url: "https://api.openai.com",
      supported_models: ["gpt-4", "gpt-3.5-turbo"]
    )
    
    @ai_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Test Credential",
      api_key: "test-key",
      preferred_model: "gpt-4"
    )
    
    @service = AiProviderTestService.new(@ai_credential)
  end

  test "should initialize with ai_credential" do
    assert_equal @ai_credential, @service.ai_credential
    assert_equal @ai_provider, @service.ai_provider
  end

  test "should perform comprehensive connection test" do
    # Mock the provider test_connectivity method
    @ai_provider.define_singleton_method(:test_connectivity) do |api_key|
      { success: true, message: "Basic connectivity successful" }
    end
    
    # Mock the model test
    @service.define_singleton_method(:test_model_access) do
      { success: true, message: "Model accessible" }
    end
    
    # Mock the prompt test
    @service.define_singleton_method(:test_simple_prompt) do
      { success: true, message: "Prompt test successful", response_preview: "Connection successful." }
    end
    
    result = @service.test_connection
    
    assert result[:success]
    assert result[:started_at].present?
    assert result[:completed_at].present?
    assert result[:duration].present?
    assert_equal @ai_credential.id, result[:credential_id]
    assert_equal "openai", result[:provider]
    
    # Check that credential was updated
    @ai_credential.reload
    assert @ai_credential.last_tested_at.present?
    assert @ai_credential.last_test_result.present?
  end

  test "should handle connection test failure" do
    # Mock the provider to return failure
    @ai_provider.define_singleton_method(:test_connectivity) do |api_key|
      { success: false, error: "Invalid API key" }
    end
    
    result = @service.test_connection
    
    assert_not result[:success]
    assert_equal "Invalid API key", result[:error]
  end

  test "should handle exceptions during test" do
    # Mock the provider to raise an exception
    @ai_provider.define_singleton_method(:test_connectivity) do |api_key|
      raise StandardError, "Network error"
    end
    
    result = @service.test_connection
    
    assert_not result[:success]
    assert_equal "Network error", result[:error]
    assert_equal "StandardError", result[:error_class]
  end

  test "should test simple prompt" do
    # Mock the job runner and its test_prompt method
    mock_runner = Minitest::Mock.new
    mock_runner.expect :test_prompt, "Connection successful.", ["Hello, this is a connectivity test. Please respond with 'Connection successful.'"]
    
    @ai_credential.define_singleton_method(:create_job_runner) do
      mock_runner
    end
    
    result = @service.test_simple_prompt
    
    assert result[:success]
    assert_equal "Prompt test successful", result[:message]
    assert_equal "Connection successful.", result[:response_preview]
    mock_runner.verify
  end

  test "should handle prompt test failure" do
    # Mock the job runner to return an error
    mock_runner = Minitest::Mock.new
    mock_runner.expect :test_prompt, { success: false, error: "Rate limit exceeded" }, [String]
    
    @ai_credential.define_singleton_method(:create_job_runner) do
      mock_runner
    end
    
    result = @service.test_simple_prompt
    
    assert_not result[:success]
    assert_equal "Rate limit exceeded", result[:error]
    mock_runner.verify
  end

  test "should check last test successful status" do
    # Set a successful test result
    @ai_credential.update!(
      last_test_result: { success: true, message: "Test passed" }.to_json
    )
    
    assert @service.last_test_successful?
    
    # Set a failed test result
    @ai_credential.update!(
      last_test_result: { success: false, error: "Test failed" }.to_json
    )
    
    assert_not @service.last_test_successful?
  end

  test "should handle invalid JSON in test result" do
    @ai_credential.update!(last_test_result: "invalid json")
    
    assert_not @service.last_test_successful?
    assert_empty @service.test_history
  end

  test "should truncate long responses" do
    long_response = "a" * 150
    truncated = @service.send(:truncate_response, long_response, 100)
    
    assert_equal 104, truncated.length # 100 chars + "..."
    assert truncated.end_with?("...")
  end

  test "should handle non-string responses" do
    hash_response = { key: "value" }
    result = @service.send(:truncate_response, hash_response, 100)
    
    assert result.include?("key")
    assert result.include?("value")
  end
end