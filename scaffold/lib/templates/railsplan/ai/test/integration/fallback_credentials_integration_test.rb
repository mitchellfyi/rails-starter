# frozen_string_literal: true

require 'test_helper'

class FallbackCredentialsIntegrationTest < ActionDispatch::IntegrationTest
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
  end

  test "should fall back to fallback credential when no user credentials exist" do
    # Create a fallback credential
    fallback_credential = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_limit: 100,
      onboarding_message: "Try our AI assistant with free credits!",
      imported_by: @user
    )

    # Should return fallback credential when looking for best credential
    best_credential = AiCredential.best_for(@workspace, "openai")
    assert_equal fallback_credential, best_credential
    assert best_credential.is_fallback?
  end

  test "should prefer user credentials over fallback" do
    # Create a fallback credential
    fallback_credential = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      imported_by: @user
    )

    # Create a user credential
    user_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "User OpenAI",
      api_key: "user-key",
      preferred_model: "gpt-4",
      is_fallback: false,
      active: true
    )

    # Should return user credential, not fallback
    best_credential = AiCredential.best_for(@workspace, "openai")
    assert_equal user_credential, best_credential
    assert_not best_credential.is_fallback?
  end

  test "should not return unavailable fallback credentials" do
    # Create an inactive fallback credential
    inactive_fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Inactive Fallback",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: false, # Inactive
      enabled_for_trials: true,
      imported_by: @user
    )

    # Should return nil when no available credentials exist
    best_credential = AiCredential.best_for(@workspace, "openai")
    assert_nil best_credential
  end

  test "should not return expired fallback credentials" do
    # Create an expired fallback credential
    expired_fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Expired Fallback",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      expires_at: 1.day.ago, # Expired
      imported_by: @user
    )

    # Should return nil when only expired credentials exist
    best_credential = AiCredential.best_for(@workspace, "openai")
    assert_nil best_credential
  end

  test "should not return over-limit fallback credentials" do
    # Create an over-limit fallback credential
    over_limit_fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Over Limit Fallback",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_limit: 100,
      fallback_usage_count: 150, # Over limit
      imported_by: @user
    )

    # Should return nil when only over-limit credentials exist
    best_credential = AiCredential.best_for(@workspace, "openai")
    assert_nil best_credential
  end

  test "should track usage when fallback credential is used" do
    fallback_credential = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_limit: 100,
      fallback_usage_count: 50,
      imported_by: @user
    )

    initial_usage = fallback_credential.usage_count
    initial_fallback_usage = fallback_credential.fallback_usage_count

    # Simulate using the credential
    fallback_credential.mark_used!
    fallback_credential.reload

    assert_equal initial_usage + 1, fallback_credential.usage_count
    assert_equal initial_fallback_usage + 1, fallback_credential.fallback_usage_count
  end

  test "should return fallback credentials in usage order" do
    # Create multiple fallback credentials with different usage counts
    fallback1 = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback 1",
      api_key: "fallback-key-1",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_count: 100,
      imported_by: @user
    )

    fallback2 = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback 2",
      api_key: "fallback-key-2",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_count: 50,
      imported_by: @user
    )

    # Should return the one with lower usage count
    best_credential = AiCredential.best_for(@workspace, "openai")
    assert_equal fallback2, best_credential
  end

  test "should check fallback enabled status" do
    # Initially no fallback credentials
    assert_not AiCredential.fallback_enabled?

    # Create a fallback credential
    AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      imported_by: @user
    )

    # Should now return true
    assert AiCredential.fallback_enabled?
  end
end