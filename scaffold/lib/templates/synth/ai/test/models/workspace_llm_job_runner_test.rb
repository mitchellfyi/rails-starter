# frozen_string_literal: true

require 'test_helper'

class WorkspaceLLMJobRunnerTest < ActiveSupport::TestCase
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
      preferred_model: "gpt-4",
      active: true,
      is_default: true
    )
    
    @runner = WorkspaceLLMJobRunner.new(@workspace)
  end

  test "should initialize with workspace" do
    assert_equal @workspace, @runner.workspace
  end

  test "should list available providers" do
    providers = @runner.available_providers
    assert_includes providers, "openai"
  end

  test "should find credential for provider" do
    credential = @runner.credential_for("openai")
    assert_equal @ai_credential, credential
  end

  test "should return nil for unknown provider" do
    credential = @runner.credential_for("unknown")
    assert_nil credential
  end

  test "should find best credential for provider" do
    credential = @runner.best_credential_for("openai")
    assert_equal @ai_credential, credential
  end

  test "should check if workspace is configured" do
    assert @runner.configured?
    
    @ai_credential.update!(active: false)
    assert_not @runner.configured?
  end

  test "should raise error when no credential found for provider" do
    @ai_credential.update!(active: false)
    
    assert_raises RuntimeError do
      @runner.run(template: "Hello", provider: "openai")
    end
  end

  test "should test all credentials" do
    # Mock the test_connection method
    @ai_credential.define_singleton_method(:test_connection) do
      { success: true, message: "Test successful" }
    end
    
    results = @runner.test_all_credentials
    assert_equal 1, results["openai"].size
    assert_equal "Test Credential", results["openai"].first[:credential_name]
    assert results["openai"].first[:test_result][:success]
  end
end