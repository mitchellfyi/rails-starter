# frozen_string_literal: true

require 'test_helper'

class CredentialValidationServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password",
      first_name: "Test",
      last_name: "User"
    )
    
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
    
    @credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Test Credential",
      api_key: "sk-test1234567890abcdefghijklmnopqrstuvwxyz",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 4096,
      response_format: "text"
    )
    
    @service = CredentialValidationService.new(@workspace)
  end

  test "should test all credentials in workspace" do
    # Mock the AiProviderTestService
    mock_test_service = Minitest::Mock.new
    mock_test_service.expect :test_connection, {
      success: true,
      message: "Connection successful",
      duration: 1.5
    }
    
    AiProviderTestService.stub :new, mock_test_service do
      results = @service.test_all_credentials
      
      assert_equal 1, results[:total_count]
      assert_equal 1, results[:successful_count]
      assert_equal 0, results[:failed_count]
      assert_equal 100.0, results[:success_rate]
      assert_equal 1, results[:credentials].length
      
      credential_result = results[:credentials].first
      assert_equal @credential.id, credential_result[:credential_id]
      assert_equal @credential.name, credential_result[:credential_name]
      assert_equal @ai_provider.name, credential_result[:provider]
      assert credential_result[:success]
    end
    
    mock_test_service.verify
  end

  test "should handle test failures gracefully" do
    # Mock failing test service
    mock_test_service = Minitest::Mock.new
    mock_test_service.expect :test_connection, {
      success: false,
      error: "API key invalid",
      duration: 0.5
    }
    
    AiProviderTestService.stub :new, mock_test_service do
      results = @service.test_all_credentials
      
      assert_equal 1, results[:total_count]
      assert_equal 0, results[:successful_count]
      assert_equal 1, results[:failed_count]
      assert_equal 0.0, results[:success_rate]
      
      credential_result = results[:credentials].first
      refute credential_result[:success]
      assert_equal "API key invalid", credential_result[:error]
    end
    
    mock_test_service.verify
  end

  test "should test single credential with validations" do
    result = @service.send(:test_single_credential, @credential)
    
    assert result[:credential_id]
    assert result[:credential_name]
    assert result[:provider]
    assert result[:started_at]
    assert result[:completed_at]
    assert result[:duration]
    assert result[:validations]
    
    # Check validation results
    validations = result[:validations]
    assert validations.any? { |v| v[:type] == 'api_key_format' }
    assert validations.any? { |v| v[:type] == 'model_support' }
    assert validations.any? { |v| v[:type] == 'temperature_range' }
    assert validations.any? { |v| v[:type] == 'max_tokens_range' }
  end

  test "should run comprehensive credential validations" do
    validations = @service.send(:run_credential_validations, @credential)
    
    # Check API key format validation
    api_key_validation = validations.find { |v| v[:type] == 'api_key_format' }
    assert api_key_validation
    assert_equal 'pass', api_key_validation[:status]
    
    # Check model support validation
    model_validation = validations.find { |v| v[:type] == 'model_support' }
    assert model_validation
    assert_equal 'pass', model_validation[:status]
    
    # Check temperature range validation
    temp_validation = validations.find { |v| v[:type] == 'temperature_range' }
    assert temp_validation
    assert_equal 'pass', temp_validation[:status]
    
    # Check max tokens range validation
    tokens_validation = validations.find { |v| v[:type] == 'max_tokens_range' }
    assert tokens_validation
    assert_equal 'pass', tokens_validation[:status]
  end

  test "should detect invalid parameter ranges" do
    # Create credential with invalid parameters
    invalid_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Invalid Credential",
      api_key: "invalid-key",
      preferred_model: "unsupported-model",
      temperature: 3.0, # Invalid: too high
      max_tokens: 200000, # Invalid: too high
      response_format: "text"
    )
    
    validations = @service.send(:run_credential_validations, invalid_credential)
    
    # Should detect invalid API key format
    api_key_validation = validations.find { |v| v[:type] == 'api_key_format' }
    assert_equal 'warning', api_key_validation[:status]
    
    # Should detect unsupported model
    model_validation = validations.find { |v| v[:type] == 'model_support' }
    assert_equal 'fail', model_validation[:status]
    
    # Should detect invalid temperature
    temp_validation = validations.find { |v| v[:type] == 'temperature_range' }
    assert_equal 'fail', temp_validation[:status]
    
    # Should detect invalid max tokens
    tokens_validation = validations.find { |v| v[:type] == 'max_tokens_range' }
    assert_equal 'fail', tokens_validation[:status]
  end

  test "should validate environment mapping" do
    # Create credential with environment source
    env_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Environment Credential",
      api_key: "sk-env1234567890abcdef",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      environment_source: "OPENAI_API_KEY"
    )
    
    # Mock environment scanner
    mock_scanner = Minitest::Mock.new
    detected_vars = {
      'OPENAI_API_KEY' => { provider: 'openai', source: 'environment' },
      'UNMAPPED_KEY' => { provider: 'anthropic', source: 'environment' }
    }
    suggestions = [
      { env_key: 'UNMAPPED_KEY', provider: @ai_provider, suggested_name: 'Test' }
    ]
    
    mock_scanner.expect :scan_environment_variables, detected_vars
    mock_scanner.expect :suggest_credential_mappings, suggestions, [Hash]
    
    EnvironmentScannerService.stub :new, mock_scanner do
      results = @service.validate_environment_mapping
      
      assert_equal 2, results[:detected_variables]
      assert_equal 1, results[:mapped_credentials]
      assert_includes results[:unmapped_variables], 'UNMAPPED_KEY'
      assert_equal 1, results[:suggestions].length
    end
    
    mock_scanner.verify
  end

  test "should validate external integrations" do
    # Mock external services
    mock_vault = Minitest::Mock.new
    mock_vault.expect :available?, true
    mock_vault.expect :connection_status, { connected: true }
    
    mock_doppler = Minitest::Mock.new
    mock_doppler.expect :available?, false
    mock_doppler.expect :connection_status, { connected: false, error: "Not configured" }
    
    mock_onepassword = Minitest::Mock.new
    mock_onepassword.expect :available?, true
    mock_onepassword.expect :connection_status, { connected: true }
    
    VaultIntegrationService.stub :new, mock_vault do
      DopplerIntegrationService.stub :new, mock_doppler do
        OnePasswordIntegrationService.stub :new, mock_onepassword do
          results = @service.validate_external_integrations
          
          assert results[:vault][:available]
          assert results[:vault][:connected]
          
          refute results[:doppler][:available]
          refute results[:doppler][:connected]
          
          assert results[:onepassword][:available]
          assert results[:onepassword][:connected]
          
          assert results[:any_available]
          assert_equal 0, results[:total_synced]
        end
      end
    end
    
    mock_vault.verify
    mock_doppler.verify
    mock_onepassword.verify
  end

  test "should handle external sync requirements" do
    # Create credential that needs external sync
    synced_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Synced Credential",
      api_key: "sk-synced123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      vault_secret_key: "test-secret",
      vault_synced_at: 2.hours.ago # Needs sync
    )
    
    # Mock sync method
    synced_credential.stub(:sync_with_external_source, { success: true, message: "Synced" }) do
      result = @service.send(:test_single_credential, synced_credential)
      
      assert result[:sync_message]
      assert_equal "Synced", result[:sync_message]
    end
  end

  test "should calculate success rate correctly" do
    # Create additional credentials
    failing_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Failing Credential",
      api_key: "sk-failing123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text"
    )
    
    # Mock mixed test results
    call_count = 0
    mock_test_service = lambda do |credential|
      call_count += 1
      mock = Minitest::Mock.new
      if call_count == 1
        mock.expect :test_connection, { success: true }
      else
        mock.expect :test_connection, { success: false, error: "Failed" }
      end
      mock
    end
    
    AiProviderTestService.stub :new, mock_test_service do
      results = @service.test_all_credentials
      
      assert_equal 2, results[:total_count]
      assert_equal 1, results[:successful_count]
      assert_equal 1, results[:failed_count]
      assert_equal 50.0, results[:success_rate]
    end
  end

  test "should handle empty workspace" do
    empty_workspace = Workspace.create!(
      name: "Empty Workspace",
      slug: "empty-workspace",
      created_by: @user
    )
    
    empty_service = CredentialValidationService.new(empty_workspace)
    results = empty_service.test_all_credentials
    
    assert_equal 0, results[:total_count]
    assert_equal 0, results[:successful_count]
    assert_equal 0, results[:failed_count]
    assert_equal 0, results[:success_rate]
    assert_empty results[:credentials]
  end
end