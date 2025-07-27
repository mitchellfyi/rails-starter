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
end