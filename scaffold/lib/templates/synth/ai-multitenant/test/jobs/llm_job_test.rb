# frozen_string_literal: true

require 'test_helper'

class LLMJobTest < ActiveJob::TestCase
  setup do
    @workspace = workspaces(:acme)
    @user = users(:john)
    @ai_provider = ai_providers(:openai)
    @ai_credential = ai_credentials(:acme_openai)
  end

  test "should enqueue LLMJob with workspace runner" do
    assert_enqueued_with(job: LLMJob) do
      LLMJob.run(
        template: "Hello {{name}}",
        workspace: @workspace,
        context: { name: "World" }
      )
    end
  end

  test "should execute job with workspace-scoped credential" do
    VCR.use_cassette("openai_completion") do
      result = perform_enqueued_jobs do
        LLMJob.perform_later(
          template: "Hello {{name}}",
          model: "gpt-3.5-turbo",
          context: { name: "World" },
          format: "text",
          user_id: @user.id,
          ai_credential_id: @ai_credential.id,
          workspace_id: @workspace.id
        )
      end

      assert result.is_a?(LLMOutput)
      assert_equal "completed", result.status
      assert_not_nil result.parsed_output
      assert_equal @workspace.id, result.workspace_id
      assert_equal @ai_credential.id, result.ai_credential_id
    end
  end

  test "should track usage statistics" do
    initial_count = AiUsageSummary.count

    VCR.use_cassette("openai_completion") do
      perform_enqueued_jobs do
        LLMJob.perform_later(
          template: "Hello {{name}}",
          model: "gpt-3.5-turbo",
          context: { name: "World" },
          user_id: @user.id,
          ai_credential_id: @ai_credential.id,
          workspace_id: @workspace.id
        )
      end
    end

    # Should create or update usage summary
    assert_operator AiUsageSummary.count, :>=, initial_count
    
    summary = AiUsageSummary.find_by(
      workspace: @workspace,
      ai_credential: @ai_credential,
      date: Date.current
    )
    
    assert summary
    assert_operator summary.requests_count, :>, 0
    assert_operator summary.tokens_used, :>, 0
  end

  test "should handle missing workspace gracefully" do
    assert_raises(ArgumentError) do
      LLMJob.run(
        template: "Hello World",
        workspace: nil,
        context: {}
      )
    end
  end

  test "should handle missing credential gracefully" do
    empty_workspace = workspaces(:empty)
    
    assert_raises(ArgumentError, /No active AI credential found/) do
      WorkspaceLLMJobRunner.new(empty_workspace).run(
        template: "Hello World",
        context: {}
      )
    end
  end

  test "should create proper execution record" do
    initial_count = PromptExecution.count

    VCR.use_cassette("openai_completion") do
      perform_enqueued_jobs do
        LLMJob.perform_later(
          template: "Hello {{name}}",
          model: "gpt-3.5-turbo",
          context: { name: "World" },
          user_id: @user.id,
          ai_credential_id: @ai_credential.id,
          workspace_id: @workspace.id
        )
      end
    end

    assert_equal initial_count + 1, PromptExecution.count
    
    execution = PromptExecution.last
    assert_equal @workspace, execution.workspace
    assert_equal @user, execution.user
    assert_equal @ai_credential, execution.ai_credential
    assert_equal "completed", execution.status
    assert_not_nil execution.output
    assert_operator execution.tokens_used, :>, 0
  end

  test "should interpolate template variables correctly" do
    job = LLMJob.new
    template = "Hello {{name}}, welcome to {{company}}!"
    context = { name: "John", company: "Acme Corp" }
    
    result = job.send(:interpolate_template, template, context)
    assert_equal "Hello John, welcome to Acme Corp!", result
  end

  test "should handle job failure gracefully" do
    # Mock API failure
    LLMJob.any_instance.stubs(:call_llm_api).raises(StandardError.new("API Error"))

    assert_raises(StandardError) do
      perform_enqueued_jobs do
        LLMJob.perform_later(
          template: "Hello World",
          model: "gpt-3.5-turbo",
          context: {},
          ai_credential_id: @ai_credential.id,
          workspace_id: @workspace.id
        )
      end
    end

    # Should update execution as failed
    execution = PromptExecution.last
    assert_equal "failed", execution.status
    assert_not_nil execution.error_message
  end

  test "should validate workspace usage limits" do
    # Set usage limit
    @workspace.update(ai_usage_limit: 100)
    
    # Create usage that exceeds limit
    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @ai_credential,
      date: Date.current,
      tokens_used: 150
    )

    runner = WorkspaceLLMJobRunner.new(@workspace)
    assert_not runner.within_limits?
    assert_equal 0, runner.remaining_usage
  end

  test "should provide cost estimation" do
    runner = WorkspaceLLMJobRunner.new(@workspace)
    estimate = runner.estimate_cost(
      template: "Hello {{name}}",
      context: { name: "World" },
      provider: "openai",
      model: "gpt-3.5-turbo"
    )

    assert estimate[:estimated_tokens]
    assert estimate[:estimated_cost]
    assert_equal "openai", estimate[:provider]
    assert_equal "gpt-3.5-turbo", estimate[:model]
  end
end