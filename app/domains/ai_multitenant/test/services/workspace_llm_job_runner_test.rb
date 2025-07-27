# frozen_string_literal: true

require 'test_helper'

class WorkspaceLLMJobRunnerTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:acme)
    @user = users(:john)
    @openai_provider = ai_providers(:openai)
    @anthropic_provider = ai_providers(:anthropic)
    @openai_credential = ai_credentials(:acme_openai)
    @runner = WorkspaceLLMJobRunner.new(@workspace)
  end

  test "should initialize with workspace" do
    assert_equal @workspace, @runner.workspace
  end

  test "should raise error with nil workspace" do
    assert_raises(ArgumentError, "Workspace cannot be nil") do
      WorkspaceLLMJobRunner.new(nil)
    end
  end

  test "should find available providers" do
    providers = @runner.available_providers
    assert_includes providers, "openai"
  end

  test "should find available models by provider" do
    models = @runner.available_models
    assert models.key?("openai")
    assert_includes models["openai"], "gpt-3.5-turbo"
    assert_includes models["openai"], "gpt-4"
  end

  test "should route to correct provider automatically" do
    # Mock job execution
    LLMJob.expects(:perform_later).with(
      template: "Hello World",
      model: "gpt-3.5-turbo",
      context: {},
      format: "text",
      user_id: @user.id,
      ai_credential_id: @openai_credential.id,
      workspace_id: @workspace.id
    )

    @runner.run(
      template: "Hello World",
      context: {},
      user: @user
    )
  end

  test "should route to specific provider when requested" do
    # Create Anthropic credential
    anthropic_credential = @workspace.ai_credentials.create!(
      ai_provider: @anthropic_provider,
      name: "Anthropic Credential",
      api_key: "sk-anthropic",
      preferred_model: "claude-3-sonnet"
    )

    LLMJob.expects(:perform_later).with(
      template: "Hello World",
      model: "claude-3-sonnet",
      context: {},
      format: "text",
      user_id: @user.id,
      ai_credential_id: anthropic_credential.id,
      workspace_id: @workspace.id
    )

    @runner.run(
      template: "Hello World",
      context: {},
      user: @user,
      provider: "anthropic"
    )
  end

  test "should validate model support for provider" do
    assert_raises(ArgumentError, /Model 'claude-3-sonnet' is not supported/) do
      @runner.run(
        template: "Hello World",
        context: {},
        user: @user,
        provider: "openai",
        model: "claude-3-sonnet"
      )
    end
  end

  test "should handle missing provider gracefully" do
    assert_raises(ArgumentError, /No active AI credential found for provider 'nonexistent'/) do
      @runner.run(
        template: "Hello World",
        context: {},
        user: @user,
        provider: "nonexistent"
      )
    end
  end

  test "should test all credentials" do
    # Mock test results
    @openai_credential.expects(:test_connection).returns({
      success: true,
      message: "Connection successful"
    })

    results = @runner.test_all_credentials
    
    assert results.key?("openai")
    assert_equal 1, results["openai"].size
    assert_equal @openai_credential.name, results["openai"].first[:credential_name]
    assert results["openai"].first[:test_result][:success]
  end

  test "should check if workspace is configured" do
    assert @runner.configured?
    
    # Empty workspace should not be configured
    empty_workspace = workspaces(:empty)
    empty_runner = WorkspaceLLMJobRunner.new(empty_workspace)
    assert_not empty_runner.configured?
  end

  test "should calculate usage statistics" do
    # Create usage data
    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @openai_credential,
      date: Date.current,
      requests_count: 10,
      tokens_used: 1000,
      estimated_cost: 0.03,
      successful_requests: 9,
      failed_requests: 1
    )

    stats = @runner.usage_stats
    assert_equal 10, stats[:total_requests]
    assert_equal 1000, stats[:total_tokens]
    assert_equal 0.03, stats[:total_cost]
    assert_equal 9, stats[:successful_requests]
  end

  test "should provide daily usage breakdown" do
    # Create usage for multiple days
    [0, 1, 2].each do |days_ago|
      AiUsageSummary.create!(
        workspace: @workspace,
        ai_credential: @openai_credential,
        date: days_ago.days.ago.to_date,
        requests_count: 10 + days_ago,
        tokens_used: (10 + days_ago) * 100,
        estimated_cost: (10 + days_ago) * 0.003,
        successful_requests: 9 + days_ago,
        failed_requests: 1
      )
    end

    daily_usage = @runner.daily_usage(7)
    assert_equal 3, daily_usage.size
    
    today_usage = daily_usage.find { |day| day[:date] == Date.current }
    assert_equal 10, today_usage[:requests_count]
    assert_equal 1000, today_usage[:tokens_used]
  end

  test "should provide provider breakdown" do
    # Create Anthropic credential and usage
    anthropic_credential = @workspace.ai_credentials.create!(
      ai_provider: @anthropic_provider,
      name: "Anthropic Credential",
      api_key: "sk-anthropic",
      preferred_model: "claude-3-sonnet"
    )

    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @openai_credential,
      date: Date.current,
      requests_count: 10,
      tokens_used: 1000,
      estimated_cost: 0.03
    )

    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: anthropic_credential,
      date: Date.current,
      requests_count: 5,
      tokens_used: 500,
      estimated_cost: 0.04
    )

    breakdown = @runner.provider_breakdown
    assert_equal 2, breakdown.size
    
    openai_data = breakdown.find { |p| p[:provider_slug] == "openai" }
    anthropic_data = breakdown.find { |p| p[:provider_slug] == "anthropic" }
    
    assert_equal 10, openai_data[:requests_count]
    assert_equal 5, anthropic_data[:requests_count]
  end

  test "should check usage limits" do
    # Set a usage limit
    @workspace.expects(:ai_usage_limit).returns(100).at_least_once
    
    # No usage yet
    assert @runner.within_limits?
    assert_equal 100, @runner.remaining_usage
    
    # Add usage that's under limit
    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @openai_credential,
      date: Date.current,
      tokens_used: 50
    )
    
    assert @runner.within_limits?
    assert_equal 50, @runner.remaining_usage
    
    # Add usage that exceeds limit
    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @openai_credential,
      date: Date.current,
      tokens_used: 60
    )
    
    # Should now be over limit
    assert_not @runner.within_limits?
    assert_equal 0, @runner.remaining_usage
  end

  test "should estimate costs accurately" do
    estimate = @runner.estimate_cost(
      template: "Hello {{name}}, how are you?",
      context: { name: "John" },
      provider: "openai",
      model: "gpt-3.5-turbo"
    )

    assert estimate[:estimated_tokens]
    assert estimate[:estimated_cost]
    assert_equal "openai", estimate[:provider]
    assert_equal "gpt-3.5-turbo", estimate[:model]
    assert_equal @openai_credential.name, estimate[:credential_name]
    
    # Should be reasonable estimate
    assert_operator estimate[:estimated_tokens], :>, 0
    assert_operator estimate[:estimated_cost], :>, 0
  end

  test "should handle synchronous execution" do
    # Mock the job execution
    mock_result = LLMOutput.new(
      parsed_output: "Hello John!",
      raw_response: "Hello John!",
      model_name: "gpt-3.5-turbo",
      status: "completed"
    )
    
    LLMJob.any_instance.expects(:perform).returns(mock_result)

    result = @runner.run_sync(
      template: "Hello {{name}}",
      context: { name: "John" },
      user: @user
    )

    assert_equal mock_result, result
  end

  test "should validate input parameters" do
    # Blank template
    assert_raises(ArgumentError, "Template cannot be blank") do
      @runner.run(template: "", context: {})
    end

    # Invalid context
    assert_raises(ArgumentError, "Context must be a Hash") do
      @runner.run(template: "Hello", context: "invalid")
    end

    # Invalid format
    assert_raises(ArgumentError, "Invalid format: invalid") do
      @runner.run(template: "Hello", context: {}, format: "invalid")
    end
  end

  test "should distribute jobs across providers when requested" do
    # Create multiple providers
    anthropic_credential = @workspace.ai_credentials.create!(
      ai_provider: @anthropic_provider,
      name: "Anthropic Credential",
      api_key: "sk-anthropic",
      preferred_model: "claude-3-sonnet"
    )

    jobs = [
      { template: "Job 1", context: {} },
      { template: "Job 2", context: {} },
      { template: "Job 3", context: {} }
    ]

    # Mock job execution to track calls
    LLMJob.expects(:perform_later).times(3)

    @runner.run_batch(jobs, distribute: true)
  end

  test "should handle workspace isolation correctly" do
    other_workspace = workspaces(:other)
    other_runner = WorkspaceLLMJobRunner.new(other_workspace)

    # Other workspace should not see our credentials
    assert_empty other_runner.available_providers
    assert_not other_runner.configured?

    # Create credential for other workspace
    other_credential = other_workspace.ai_credentials.create!(
      ai_provider: @openai_provider,
      name: "Other OpenAI",
      api_key: "sk-other",
      preferred_model: "gpt-4"
    )

    # Now other workspace should be configured but only see its own credentials
    assert other_runner.configured?
    assert_includes other_runner.available_providers, "openai"
    
    # But credentials should be isolated
    our_credential = @runner.credential_for("openai")
    their_credential = other_runner.credential_for("openai")
    
    assert_equal @openai_credential.id, our_credential.id
    assert_equal other_credential.id, their_credential.id
    assert_not_equal our_credential.id, their_credential.id
  end
end