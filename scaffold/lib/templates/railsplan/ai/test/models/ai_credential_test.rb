# frozen_string_literal: true

require 'test_helper'

class AiCredentialTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(
      name: "Test Workspace",
      slug: "test-workspace",
      created_by: User.create!(email: "test@example.com", password: "password")
    )
    
    @ai_provider = AiProvider.create!(
      name: "OpenAI",
      slug: "openai",
      api_base_url: "https://api.openai.com",
      supported_models: ["gpt-4", "gpt-3.5-turbo"]
    )
    
    @ai_credential = AiCredential.new(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Test Credential",
      api_key: "test-api-key",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text"
    )
  end

  test "should be valid with required attributes" do
    assert @ai_credential.valid?
  end

  test "should require name" do
    @ai_credential.name = nil
    assert_not @ai_credential.valid?
    assert_includes @ai_credential.errors[:name], "can't be blank"
  end

  test "should require unique name per workspace and provider" do
    @ai_credential.save!
    duplicate = AiCredential.new(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: @ai_credential.name,
      api_key: "different-key",
      preferred_model: "gpt-3.5-turbo"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name in different workspaces" do
    @ai_credential.save!
    
    other_workspace = Workspace.create!(
      name: "Other Workspace",
      slug: "other-workspace",
      created_by: @workspace.created_by
    )
    
    other_credential = AiCredential.new(
      workspace: other_workspace,
      ai_provider: @ai_provider,
      name: @ai_credential.name,
      api_key: "other-key",
      preferred_model: "gpt-4"
    )
    assert other_credential.valid?
  end

  test "should validate temperature range" do
    @ai_credential.temperature = 2.5
    assert_not @ai_credential.valid?
    assert_includes @ai_credential.errors[:temperature], "is not included in the list"
    
    @ai_credential.temperature = 1.5
    assert @ai_credential.valid?
  end

  test "should validate max_tokens range" do
    @ai_credential.max_tokens = 0
    assert_not @ai_credential.valid?
    assert_includes @ai_credential.errors[:max_tokens], "is not included in the list"
    
    @ai_credential.max_tokens = 150000
    assert_not @ai_credential.valid?
    
    @ai_credential.max_tokens = 4096
    assert @ai_credential.valid?
  end

  test "should validate model is supported by provider" do
    @ai_credential.preferred_model = "unsupported-model"
    assert_not @ai_credential.valid?
    assert_includes @ai_credential.errors[:preferred_model], "is not supported by OpenAI"
  end

  test "should only allow one default per provider per workspace" do
    @ai_credential.is_default = true
    @ai_credential.save!
    
    other_credential = AiCredential.new(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Other Credential",
      api_key: "other-key",
      preferred_model: "gpt-3.5-turbo",
      is_default: true
    )
    
    assert_not other_credential.valid?
    assert_includes other_credential.errors[:is_default], "only one default credential allowed per provider in a workspace"
  end

  test "should find default credential for workspace and provider" do
    @ai_credential.is_default = true
    @ai_credential.save!
    
    found = AiCredential.default_for(@workspace, "openai")
    assert_equal @ai_credential, found
  end

  test "should find best credential for workspace and provider" do
    @ai_credential.save!
    
    # Should return the only credential when no default exists
    found = AiCredential.best_for(@workspace, "openai")
    assert_equal @ai_credential, found
    
    # Should prefer default when available
    default_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Default Credential",
      api_key: "default-key",
      preferred_model: "gpt-4",
      is_default: true
    )
    
    found = AiCredential.best_for(@workspace, "openai")
    assert_equal default_credential, found
  end

  test "should return api config" do
    @ai_credential.provider_config = { custom_setting: "value" }
    config = @ai_credential.api_config
    
    assert_equal "gpt-4", config[:model]
    assert_equal 0.7, config[:temperature]
    assert_equal 1000, config[:max_tokens]
    assert_equal "value", config[:custom_setting]
  end

  test "should return full config including credentials" do
    config = @ai_credential.full_config
    
    assert_equal "test-api-key", config[:api_key]
    assert_equal "openai", config[:provider]
    assert_equal "https://api.openai.com", config[:base_url]
    assert_equal "gpt-4", config[:model]
  end

  test "should mark as used" do
    initial_count = @ai_credential.usage_count
    initial_time = @ai_credential.last_used_at
    
    @ai_credential.mark_used!
    @ai_credential.reload
    
    assert_equal initial_count + 1, @ai_credential.usage_count
    assert @ai_credential.last_used_at > initial_time if initial_time
  end

  test "should create job runner" do
    runner = @ai_credential.create_job_runner
    assert_instance_of AiCredentialJobRunner, runner
    assert_equal @ai_credential, runner.ai_credential
  end

  # Fallback credential tests
  test "should create fallback credential without workspace" do
    fallback = AiCredential.new(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      fallback_usage_limit: 100
    )
    
    assert fallback.valid?
    assert fallback.is_fallback?
  end

  test "should not allow fallback credential with workspace" do
    fallback = AiCredential.new(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Invalid Fallback",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true
    )
    
    assert_not fallback.valid?
    assert_includes fallback.errors[:workspace], "fallback credentials cannot be associated with a workspace"
  end

  test "should validate fallback usage limit" do
    fallback = AiCredential.new(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      fallback_usage_limit: -10
    )
    
    assert_not fallback.valid?
    assert_includes fallback.errors[:fallback_usage_limit], "must be greater than 0"
  end

  test "should find available fallback credentials" do
    fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_limit: 100,
      fallback_usage_count: 50
    )
    
    available = AiCredential.available_fallbacks
    assert_includes available, fallback
  end

  test "should not include expired fallback credentials" do
    fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Expired Fallback",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      expires_at: 1.day.ago
    )
    
    available = AiCredential.available_fallbacks
    assert_not_includes available, fallback
  end

  test "should not include over-limit fallback credentials" do
    fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Over Limit Fallback",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_limit: 100,
      fallback_usage_count: 150
    )
    
    available = AiCredential.available_fallbacks
    assert_not_includes available, fallback
  end

  test "should find best fallback for provider" do
    # Create two fallback credentials with different usage counts
    fallback1 = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback 1",
      api_key: "fallback-key-1",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_count: 100
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
      fallback_usage_count: 50
    )
    
    # Should return the one with lower usage count
    best = AiCredential.best_fallback_for_provider("openai")
    assert_equal fallback2, best
  end

  test "should fall back to fallback credentials when no user credentials exist" do
    fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true
    )
    
    # Should return fallback when no user credentials exist
    best = AiCredential.best_for(@workspace, "openai")
    assert_equal fallback, best
  end

  test "should prefer user credentials over fallback credentials" do
    # Create user credential
    @ai_credential.save!
    
    # Create fallback credential
    fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true
    )
    
    # Should return user credential, not fallback
    best = AiCredential.best_for(@workspace, "openai")
    assert_equal @ai_credential, best
  end

  test "should check if credential is available" do
    # Regular credential should be available when active
    @ai_credential.active = true
    assert @ai_credential.available?
    
    # Regular credential should not be available when inactive
    @ai_credential.active = false
    assert_not @ai_credential.available?
    
    # Fallback credential should be available when conditions are met
    fallback = AiCredential.new(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_limit: 100,
      fallback_usage_count: 50
    )
    assert fallback.available?
    
    # Fallback should not be available when expired
    fallback.expires_at = 1.day.ago
    assert_not fallback.available?
  end

  test "should calculate remaining usage for fallback credentials" do
    fallback = AiCredential.new(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      fallback_usage_limit: 100,
      fallback_usage_count: 30
    )
    
    assert_equal 70, fallback.remaining_usage
    
    # Should return infinity for unlimited fallback
    fallback.fallback_usage_limit = nil
    assert_equal Float::INFINITY, fallback.remaining_usage
    
    # Should return infinity for regular credentials
    assert_equal Float::INFINITY, @ai_credential.remaining_usage
  end

  test "should track fallback usage when marked as used" do
    fallback = AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true,
      active: true,
      enabled_for_trials: true,
      fallback_usage_count: 0
    )
    
    initial_usage = fallback.usage_count
    initial_fallback_usage = fallback.fallback_usage_count
    
    fallback.mark_used!
    fallback.reload
    
    assert_equal initial_usage + 1, fallback.usage_count
    assert_equal initial_fallback_usage + 1, fallback.fallback_usage_count
  end

  test "should not track fallback usage for regular credentials" do
    @ai_credential.save!
    initial_fallback_usage = @ai_credential.fallback_usage_count
    
    @ai_credential.mark_used!
    @ai_credential.reload
    
    # Fallback usage count should not change for regular credentials
    assert_equal initial_fallback_usage, @ai_credential.fallback_usage_count
  end

  test "should check if fallback credentials are enabled" do
    # Should return false when no fallback credentials exist
    assert_not AiCredential.fallback_enabled?
    
    # Should return true when fallback credentials exist
    AiCredential.create!(
      workspace: nil,
      ai_provider: @ai_provider,
      name: "Fallback OpenAI",
      api_key: "fallback-key",
      preferred_model: "gpt-4",
      is_fallback: true
    )
    
    assert AiCredential.fallback_enabled?
  end
end