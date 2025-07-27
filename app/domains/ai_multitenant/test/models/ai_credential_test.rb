# frozen_string_literal: true

require 'test_helper'

class AiCredentialTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:acme)
    @ai_provider = ai_providers(:openai)
    @ai_credential = ai_credentials(:acme_openai)
  end

  test "should encrypt API key on creation" do
    credential = @workspace.ai_credentials.build(
      ai_provider: @ai_provider,
      name: "Test Credential",
      api_key: "sk-test123",
      preferred_model: "gpt-3.5-turbo"
    )

    credential.save!
    
    # API key should be encrypted
    assert_not_nil credential.encrypted_api_key
    assert_not_equal "sk-test123", credential.encrypted_api_key
    
    # Should be able to decrypt
    assert_equal "sk-test123", credential.api_key_decrypted
  end

  test "should validate unique default per provider per workspace" do
    # Create first default credential
    credential1 = @workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "First Default",
      api_key: "sk-test1",
      preferred_model: "gpt-3.5-turbo",
      is_default: true
    )

    # Second default credential for same provider should fail
    credential2 = @workspace.ai_credentials.build(
      ai_provider: @ai_provider,
      name: "Second Default",
      api_key: "sk-test2",
      preferred_model: "gpt-4",
      is_default: true
    )

    assert_not credential2.valid?
    assert_includes credential2.errors[:is_default], "can only have one default credential per provider per workspace"
  end

  test "should allow multiple default credentials for different providers" do
    anthropic_provider = ai_providers(:anthropic)
    
    # OpenAI default
    openai_credential = @workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "OpenAI Default",
      api_key: "sk-openai",
      preferred_model: "gpt-3.5-turbo",
      is_default: true
    )

    # Anthropic default
    anthropic_credential = @workspace.ai_credentials.create!(
      ai_provider: anthropic_provider,
      name: "Anthropic Default",
      api_key: "sk-anthropic",
      preferred_model: "claude-3-sonnet",
      is_default: true
    )

    assert openai_credential.valid?
    assert anthropic_credential.valid?
  end

  test "should find best credential for workspace and provider" do
    # Create multiple credentials
    recent_credential = @workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "Recent Credential",
      api_key: "sk-recent",
      preferred_model: "gpt-4",
      last_used_at: 1.hour.ago
    )

    old_credential = @workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "Old Credential",
      api_key: "sk-old",
      preferred_model: "gpt-3.5-turbo",
      last_used_at: 1.day.ago
    )

    default_credential = @workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "Default Credential",
      api_key: "sk-default",
      preferred_model: "gpt-4",
      is_default: true
    )

    # Should return default credential first
    best = AiCredential.best_for(@workspace, "openai")
    assert_equal default_credential, best
  end

  test "should validate model support" do
    credential = ai_credentials(:acme_openai)
    
    assert credential.supports_model?("gpt-3.5-turbo")
    assert credential.supports_model?("gpt-4")
    assert_not credential.supports_model?("claude-3-sonnet")
  end

  test "should test connection and record result" do
    credential = @ai_credential
    
    # Mock successful test
    AiProviderTestService.any_instance.stubs(:test_credential).returns({
      success: true,
      message: "Connection successful",
      response_time: 0.5
    })

    result = credential.test_connection
    
    assert result[:success]
    assert_equal "Connection successful", result[:message]
    
    # Should create test record
    test_record = credential.ai_credential_tests.last
    assert test_record.successful?
    assert_not_nil credential.last_tested_at
  end

  test "should calculate usage statistics" do
    # Create usage summaries
    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @ai_credential,
      date: Date.current,
      tokens_used: 1000,
      estimated_cost: 0.03,
      successful_requests: 10,
      failed_requests: 1
    )

    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @ai_credential,
      date: 1.day.ago.to_date,
      tokens_used: 500,
      estimated_cost: 0.015,
      successful_requests: 5,
      failed_requests: 0
    )

    assert_equal 1500, @ai_credential.total_usage(2.days.ago..Time.current)
    assert_equal 0.045, @ai_credential.total_cost(2.days.ago..Time.current)
    assert_equal 93.75, @ai_credential.success_rate(2.days.ago..Time.current) # 15/16 * 100
  end

  test "should prevent deletion of last credential for provider" do
    # Remove other credentials
    @workspace.ai_credentials.where.not(id: @ai_credential.id).destroy_all
    
    assert_not @ai_credential.can_be_deleted?
    
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      @ai_credential.destroy!
    end
  end

  test "should allow deletion when other credentials exist" do
    # Create another credential
    @workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "Another Credential",
      api_key: "sk-another",
      preferred_model: "gpt-4"
    )

    assert @ai_credential.can_be_deleted?
    assert @ai_credential.destroy
  end

  test "should set first credential as default automatically" do
    new_workspace = Workspace.create!(name: "Test Workspace")
    
    credential = new_workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "First Credential",
      api_key: "sk-first",
      preferred_model: "gpt-3.5-turbo"
    )

    assert credential.is_default?
  end

  test "should validate workspace isolation" do
    other_workspace = workspaces(:other)
    
    # Should not find credentials from other workspace
    credential = AiCredential.best_for(other_workspace, "openai")
    assert_nil credential
    
    # Create credential for other workspace
    other_credential = other_workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "Other Workspace Credential",
      api_key: "sk-other",
      preferred_model: "gpt-3.5-turbo"
    )

    # Should find the correct credential for each workspace
    acme_credential = AiCredential.best_for(@workspace, "openai")
    other_credential_found = AiCredential.best_for(other_workspace, "openai")
    
    assert_equal @ai_credential.id, acme_credential.id
    assert_equal other_credential.id, other_credential_found.id
    assert_not_equal acme_credential.id, other_credential_found.id
  end

  test "should encrypt and decrypt API keys securely" do
    original_key = "sk-test123456789"
    
    credential = @workspace.ai_credentials.create!(
      ai_provider: @ai_provider,
      name: "Secure Test",
      api_key: original_key,
      preferred_model: "gpt-3.5-turbo"
    )

    # Encrypted value should be different
    assert_not_equal original_key, credential.encrypted_api_key
    
    # Should decrypt correctly
    assert_equal original_key, credential.api_key_decrypted
    
    # Should handle tampering gracefully
    credential.update_column(:encrypted_api_key, "invalid_encrypted_data")
    assert_nil credential.api_key_decrypted
  end
end