# frozen_string_literal: true

require 'test_helper'

class Admin::FallbackCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = User.create!(
      email: "admin@example.com",
      password: "password"
      # Add admin role assignment based on your user model
    )
    
    @ai_provider = AiProvider.create!(
      name: "OpenAI",
      slug: "openai",
      api_base_url: "https://api.openai.com",
      supported_models: ["gpt-4", "gpt-3.5-turbo"]
    )
    
    @fallback_credential = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Test Fallback",
      api_key: "test-fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_limit: 100,
      imported_by: @admin_user
    )
    
    # Mock admin authentication - adjust based on your auth system
    sign_in @admin_user if respond_to?(:sign_in)
  end

  test "should get index" do
    get admin_fallback_credentials_url
    assert_response :success
    assert_select "h1", text: "Fallback AI Credentials"
  end

  test "should show fallback credential" do
    get admin_fallback_credential_url(@fallback_credential)
    assert_response :success
    assert_select "h1", text: @fallback_credential.name
  end

  test "should get new" do
    get new_admin_fallback_credential_url
    assert_response :success
    assert_select "h1", text: "New Fallback Credential"
  end

  test "should create fallback credential" do
    assert_difference('AiCredential.fallback.count') do
      post admin_fallback_credentials_url, params: {
        ai_credential: {
          name: "New Fallback",
          ai_provider_id: @ai_provider.id,
          api_key: "new-fallback-key",
          preferred_model: "gpt-4",
          temperature: 0.7,
          max_tokens: 4096,
          response_format: "text",
          fallback_usage_limit: 200,
          enabled_for_trials: true,
          active: true
        }
      }
    end

    assert_redirected_to admin_fallback_credentials_url
    
    created_credential = AiCredential.fallback.last
    assert_equal "New Fallback", created_credential.name
    assert created_credential.is_fallback?
    assert_nil created_credential.workspace
  end

  test "should not create fallback credential with invalid data" do
    assert_no_difference('AiCredential.fallback.count') do
      post admin_fallback_credentials_url, params: {
        ai_credential: {
          name: "", # Invalid - blank name
          ai_provider_id: @ai_provider.id,
          api_key: "key",
          preferred_model: "gpt-4"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_admin_fallback_credential_url(@fallback_credential)
    assert_response :success
    assert_select "h1", text: "Edit Fallback Credential"
  end

  test "should update fallback credential" do
    patch admin_fallback_credential_url(@fallback_credential), params: {
      ai_credential: {
        name: "Updated Fallback",
        fallback_usage_limit: 300
      }
    }

    assert_redirected_to admin_fallback_credential_url(@fallback_credential)
    
    @fallback_credential.reload
    assert_equal "Updated Fallback", @fallback_credential.name
    assert_equal 300, @fallback_credential.fallback_usage_limit
  end

  test "should not update fallback credential with invalid data" do
    patch admin_fallback_credential_url(@fallback_credential), params: {
      ai_credential: {
        name: "", # Invalid - blank name
        fallback_usage_limit: -10 # Invalid - negative limit
      }
    }

    assert_response :unprocessable_entity
    
    @fallback_credential.reload
    assert_not_equal "", @fallback_credential.name
  end

  test "should toggle active status" do
    original_status = @fallback_credential.active?
    
    patch toggle_active_admin_fallback_credential_url(@fallback_credential)
    
    assert_redirected_to admin_fallback_credentials_url
    
    @fallback_credential.reload
    assert_equal !original_status, @fallback_credential.active?
  end

  test "should destroy fallback credential" do
    assert_difference('AiCredential.fallback.count', -1) do
      delete admin_fallback_credential_url(@fallback_credential)
    end

    assert_redirected_to admin_fallback_credentials_url
  end

  test "should test connection" do
    # Mock the test connection service
    mock_service = Minitest::Mock.new
    mock_service.expect :test_connection, { success: true }
    
    AiProviderTestService.stub :new, mock_service do
      post test_connection_admin_fallback_credential_url(@fallback_credential)
    end
    
    assert_redirected_to admin_fallback_credential_url(@fallback_credential)
    mock_service.verify
  end

  test "should handle failed connection test" do
    # Mock the test connection service with failure
    mock_service = Minitest::Mock.new
    mock_service.expect :test_connection, { success: false, error: "Invalid API key" }
    
    AiProviderTestService.stub :new, mock_service do
      post test_connection_admin_fallback_credential_url(@fallback_credential)
    end
    
    assert_redirected_to admin_fallback_credential_url(@fallback_credential)
    mock_service.verify
  end

  test "should only allow access to fallback credentials" do
    # Create a regular (non-fallback) credential
    regular_credential = AiCredential.create!(
      workspace: Workspace.create!(
        name: "Test Workspace",
        slug: "test-workspace",
        created_by: @admin_user
      ),
      ai_provider: @ai_provider,
      name: "Regular Credential",
      api_key: "regular-key",
      preferred_model: "gpt-4",
      is_fallback: false
    )

    # Should raise RecordNotFound when trying to access regular credential through fallback controller
    assert_raises(ActiveRecord::RecordNotFound) do
      get admin_fallback_credential_url(regular_credential)
    end
  end
end