# frozen_string_literal: true

require 'test_helper'

class AiCredentialEnvironmentTest < ActiveSupport::TestCase
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
  end

  test "should support environment source tracking" do
    credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Environment Test",
      api_key: "sk-test123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      environment_source: "OPENAI_API_KEY",
      imported_at: Time.current,
      imported_by: @user
    )
    
    assert credential.imported_from_environment?
    assert_equal "OPENAI_API_KEY", credential.environment_source
    assert_equal @user, credential.imported_by
    assert_not_nil credential.imported_at
  end

  test "should support vault integration fields" do
    credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Vault Test",
      api_key: "sk-vault123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      vault_secret_key: "secret/ai/openai",
      vault_synced_at: Time.current
    )
    
    assert credential.synced_from_external?
    assert_equal "Vault", credential.external_source
    assert_equal "secret/ai/openai", credential.vault_secret_key
    assert_not_nil credential.vault_synced_at
  end

  test "should support doppler integration fields" do
    credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Doppler Test",
      api_key: "sk-doppler123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      doppler_secret_name: "OPENAI_API_KEY",
      doppler_synced_at: Time.current
    )
    
    assert credential.synced_from_external?
    assert_equal "Doppler", credential.external_source
    assert_equal "OPENAI_API_KEY", credential.doppler_secret_name
    assert_not_nil credential.doppler_synced_at
  end

  test "should support onepassword integration fields" do
    credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "1Password Test",
      api_key: "sk-onepass123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      onepassword_item_id: "abcd1234",
      onepassword_synced_at: Time.current
    )
    
    assert credential.synced_from_external?
    assert_equal "1Password", credential.external_source
    assert_equal "abcd1234", credential.onepassword_item_id
    assert_not_nil credential.onepassword_synced_at
  end

  test "should detect when external sync is needed" do
    # Recent sync - should not need sync
    recent_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Recent Sync",
      api_key: "sk-recent123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      vault_secret_key: "recent",
      vault_synced_at: 30.minutes.ago
    )
    
    refute recent_credential.needs_external_sync?
    
    # Old sync - should need sync
    old_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Old Sync",
      api_key: "sk-old123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      vault_secret_key: "old",
      vault_synced_at: 2.hours.ago
    )
    
    assert old_credential.needs_external_sync?
    
    # Never synced - should need sync
    never_synced = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Never Synced",
      api_key: "sk-never123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      vault_secret_key: "never"
    )
    
    assert never_synced.needs_external_sync?
  end

  test "should scope credentials by source type" do
    # Create various credential types
    env_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Environment",
      api_key: "sk-env123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      environment_source: "ENV_VAR"
    )
    
    vault_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Vault",
      api_key: "sk-vault123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      vault_secret_key: "vault_key"
    )
    
    doppler_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Doppler",
      api_key: "sk-doppler123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      doppler_secret_name: "doppler_key"
    )
    
    onepass_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "1Password",
      api_key: "sk-onepass123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      onepassword_item_id: "onepass_id"
    )
    
    manual_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Manual",
      api_key: "sk-manual123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text"
    )
    
    # Test scopes
    assert_includes AiCredential.imported_from_environment, env_credential
    refute_includes AiCredential.imported_from_environment, manual_credential
    
    assert_includes AiCredential.synced_from_vault, vault_credential
    refute_includes AiCredential.synced_from_vault, manual_credential
    
    assert_includes AiCredential.synced_from_doppler, doppler_credential
    refute_includes AiCredential.synced_from_doppler, manual_credential
    
    assert_includes AiCredential.synced_from_onepassword, onepass_credential
    refute_includes AiCredential.synced_from_onepassword, manual_credential
  end

  test "should mock external sync operations" do
    credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Sync Test",
      api_key: "sk-sync123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      vault_secret_key: "test_key"
    )
    
    # Mock the sync method to avoid external dependencies in tests
    mock_result = { success: true, message: "Synced successfully" }
    credential.stub(:sync_with_vault, mock_result) do
      result = credential.sync_with_external_source
      assert result[:success]
      assert_equal "Synced successfully", result[:message]
    end
  end

  test "should handle external source identification" do
    # Test various external sources
    vault_cred = AiCredential.new(vault_secret_key: "vault_key")
    assert_equal "Vault", vault_cred.external_source
    
    doppler_cred = AiCredential.new(doppler_secret_name: "doppler_key")
    assert_equal "Doppler", doppler_cred.external_source
    
    onepass_cred = AiCredential.new(onepassword_item_id: "onepass_id")
    assert_equal "1Password", onepass_cred.external_source
    
    env_cred = AiCredential.new(environment_source: "ENV_VAR")
    assert_equal "Environment", env_cred.external_source
    
    manual_cred = AiCredential.new
    assert_equal "Manual", manual_cred.external_source
  end

  test "should support imported_by association" do
    credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Association Test",
      api_key: "sk-assoc123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text",
      imported_by: @user
    )
    
    assert_equal @user, credential.imported_by
    assert_equal @user.id, credential.imported_by_id
  end
end