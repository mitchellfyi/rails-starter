# frozen_string_literal: true

require 'test_helper'

class LlmJobRoutingTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123'
    )
    @workspace = Workspace.create!(name: 'Test Workspace')
    @routing_policy = AiRoutingPolicy.create!(
      workspace: @workspace,
      name: 'Test Routing Policy',
      primary_model: 'gpt-4',
      fallback_models: ['gpt-3.5-turbo'],
      cost_threshold_warning: 0.05,
      cost_threshold_block: 0.10,
      created_by: @user,
      updated_by: @user
    )
    @spending_limit = WorkspaceSpendingLimit.create!(
      workspace: @workspace,
      daily_limit: 10.00,
      created_by: @user,
      updated_by: @user
    )
  end

  test "should use routing policy when workspace provided" do
    job = LLMJob.new
    
    # Mock the routing policy execution
    routing_policy = @routing_policy
    expected_response = {
      raw: "Test response",
      parsed: "Test response",
      estimated_cost: 0.03,
      cost_warning_triggered: false
    }
    expected_routing_decision = {
      policy_used: true,
      primary_model: 'gpt-4',
      final_model: 'gpt-4',
      total_attempts: 1
    }
    
    job.expects(:execute_with_routing_policy).returns([expected_response, expected_routing_decision])
    
    # Mock other job methods
    job.stubs(:build_mcp_context).returns({})
    job.stubs(:find_prompt_template).returns("Test template")
    job.stubs(:interpolate_template).returns("Test prompt")
    job.stubs(:estimate_tokens).returns(100)
    job.stubs(:determine_max_tokens).returns(500)
    job.stubs(:store_output).returns(LLMOutput.new)
    
    result = job.perform(
      template: "test_template",
      model: "gpt-4",
      workspace_id: @workspace.id
    )
    
    assert_not_nil result
  end

  test "should estimate tokens correctly" do
    job = LLMJob.new
    text = "This is a test prompt with some words"
    tokens = job.send(:estimate_tokens, text)
    
    expected_tokens = text.length / 4
    assert_equal expected_tokens, tokens
  end

  test "should handle cost warnings in routing policy" do
    @routing_policy.update!(cost_threshold_warning: 0.01) # Very low threshold
    
    job = LLMJob.new
    
    # Mock API call to return successful response but with cost warning
    job.stubs(:call_llm_api).returns({
      raw: "Test response",
      parsed: "Test response"
    })
    
    response, routing_decision = job.send(
      :execute_with_routing_policy,
      @routing_policy,
      "Test prompt",
      "text",
      100, # input tokens
      500  # max output tokens
    )
    
    assert response[:cost_warning_triggered]
  end

  test "should try fallback models on failure" do
    job = LLMJob.new
    
    # Mock first call to fail, second to succeed
    job.stubs(:call_llm_api).raises(StandardError.new("API Error")).then.returns({
      raw: "Fallback response",
      parsed: "Fallback response"
    })
    
    response, routing_decision = job.send(
      :execute_with_routing_policy,
      @routing_policy,
      "Test prompt",
      "text",
      100, # input tokens
      500  # max output tokens
    )
    
    assert_equal 2, routing_decision[:total_attempts]
    assert_equal 'gpt-3.5-turbo', routing_decision[:final_model]
  end

  test "should block requests exceeding cost threshold" do
    @routing_policy.update!(cost_threshold_block: 0.01) # Very low threshold
    
    job = LLMJob.new
    
    response, routing_decision = job.send(
      :execute_with_routing_policy,
      @routing_policy,
      "Test prompt",
      "text",
      1000, # Many input tokens to trigger high cost
      1000  # Many output tokens to trigger high cost
    )
    
    assert_equal 'fallback', routing_decision[:final_model]
    assert_includes response[:error], "Cost threshold exceeded"
  end

  test "should update workspace spending when job completes" do
    llm_output = LLMOutput.create!(
      template_name: 'test',
      model_name: 'gpt-4',
      format: 'text',
      status: 'completed',
      job_id: 'test-job',
      workspace: @workspace
    )
    
    initial_spend = @spending_limit.current_daily_spend
    
    llm_output.update_actual_cost!(0.05)
    
    @spending_limit.reload
    assert_equal initial_spend + 0.05, @spending_limit.current_daily_spend
  end
end