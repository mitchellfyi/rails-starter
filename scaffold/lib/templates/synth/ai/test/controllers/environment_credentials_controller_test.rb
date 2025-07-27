# frozen_string_literal: true

require 'test_helper'

class EnvironmentCredentialsControllerTest < ActionDispatch::IntegrationTest
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
    
    @membership = Membership.create!(
      user: @user,
      workspace: @workspace,
      role: "admin",
      active: true
    )
    
    @ai_provider = AiProvider.create!(
      name: "OpenAI",
      slug: "openai",
      api_base_url: "https://api.openai.com",
      supported_models: ["gpt-4", "gpt-3.5-turbo"]
    )
    
    sign_in @user
  end

  test "should get index with detected environment variables" do
    # Mock environment variables
    ENV.stub(:[]) do |key|
      case key
      when 'OPENAI_API_KEY'
        'sk-test1234567890abcdef'
      else
        nil
      end
    end
    
    get workspace_environment_credentials_path(@workspace)
    assert_response :success
    assert_select 'h1', 'Environment Credentials'
  end

  test "should require admin privileges" do
    # Change user to non-admin
    @membership.update!(role: "member")
    
    get workspace_environment_credentials_path(@workspace)
    assert_redirected_to root_path
    assert_match /access denied/i, flash[:alert]
  end

  test "should get import wizard" do
    get import_wizard_workspace_environment_credentials_path(@workspace)
    assert_response :success
    assert_select 'h1', 'Import Environment Variables'
  end

  test "should import credentials from mappings" do
    ENV.stub(:[]) do |key|
      case key
      when 'OPENAI_API_KEY'
        'sk-test1234567890abcdef'
      else
        nil
      end
    end
    
    mapping_params = {
      mappings: {
        "0" => {
          enabled: "1",
          env_key: "OPENAI_API_KEY",
          env_source: "environment",
          provider_id: @ai_provider.id.to_s,
          name: "OpenAI Test",
          model: "gpt-4",
          temperature: "0.7",
          max_tokens: "4096",
          response_format: "text",
          test_immediately: "1"
        }
      }
    }
    
    assert_difference '@workspace.ai_credentials.count', 1 do
      post import_workspace_environment_credentials_path(@workspace), params: mapping_params
    end
    
    assert_redirected_to workspace_ai_credentials_path(@workspace)
    assert_match /successfully imported/i, flash[:notice]
    
    credential = @workspace.ai_credentials.last
    assert_equal "OpenAI Test", credential.name
    assert_equal "OPENAI_API_KEY", credential.environment_source
    assert_equal @user, credential.imported_by
  end

  test "should handle import errors gracefully" do
    # Test with invalid provider ID
    mapping_params = {
      mappings: {
        "0" => {
          enabled: "1",
          env_key: "INVALID_KEY",
          provider_id: "999999"
        }
      }
    }
    
    assert_no_difference '@workspace.ai_credentials.count' do
      post import_workspace_environment_credentials_path(@workspace), params: mapping_params
    end
    
    assert_redirected_to workspace_environment_credentials_path(@workspace)
    assert_match /import failed/i, flash[:alert]
  end

  test "should get external secrets page" do
    get external_secrets_workspace_environment_credentials_path(@workspace)
    assert_response :success
  end

  test "should sync from vault when available" do
    # Mock Vault service
    mock_service = Minitest::Mock.new
    mock_service.expect :available?, true
    mock_service.expect :sync_secrets_to_workspace, { success: true, synced_count: 2 }, [@workspace]
    
    VaultIntegrationService.stub :new, mock_service do
      post sync_vault_workspace_environment_credentials_path(@workspace)
    end
    
    assert_redirected_to workspace_environment_credentials_path(@workspace)
    assert_match /successfully synced 2 secrets/i, flash[:notice]
    mock_service.verify
  end

  test "should handle vault sync failure" do
    # Mock Vault service failure
    mock_service = Minitest::Mock.new
    mock_service.expect :available?, true
    mock_service.expect :sync_secrets_to_workspace, { success: false, error: "Connection failed" }, [@workspace]
    
    VaultIntegrationService.stub :new, mock_service do
      post sync_vault_workspace_environment_credentials_path(@workspace)
    end
    
    assert_redirected_to workspace_environment_credentials_path(@workspace)
    assert_match /vault sync failed/i, flash[:alert]
    mock_service.verify
  end

  test "should sync from doppler when available" do
    mock_service = Minitest::Mock.new
    mock_service.expect :available?, true
    mock_service.expect :sync_secrets_to_workspace, { success: true, synced_count: 1 }, [@workspace]
    
    DopplerIntegrationService.stub :new, mock_service do
      post sync_doppler_workspace_environment_credentials_path(@workspace)
    end
    
    assert_redirected_to workspace_environment_credentials_path(@workspace)
    assert_match /successfully synced 1 secrets/i, flash[:notice]
    mock_service.verify
  end

  test "should sync from onepassword when available" do
    mock_service = Minitest::Mock.new
    mock_service.expect :available?, true
    mock_service.expect :sync_secrets_to_workspace, { success: true, synced_count: 3 }, [@workspace]
    
    OnePasswordIntegrationService.stub :new, mock_service do
      post sync_onepassword_workspace_environment_credentials_path(@workspace)
    end
    
    assert_redirected_to workspace_environment_credentials_path(@workspace)
    assert_match /successfully synced 3 secrets/i, flash[:notice]
    mock_service.verify
  end

  test "should test all credentials" do
    # Create test credentials
    credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Test Credential",
      api_key: "sk-test1234567890abcdef",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text"
    )
    
    # Mock validation service
    mock_service = Minitest::Mock.new
    mock_results = {
      total_count: 1,
      successful_count: 1,
      failed_count: 0,
      success_rate: 100.0,
      credentials: [
        {
          credential_id: credential.id,
          success: true,
          message: "Connection successful"
        }
      ]
    }
    mock_service.expect :test_all_credentials, mock_results
    
    CredentialValidationService.stub :new, mock_service do
      post test_all_credentials_workspace_environment_credentials_path(@workspace), xhr: true
    end
    
    assert_response :success
    mock_service.verify
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password'
      }
    }
  end
end