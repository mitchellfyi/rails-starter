# frozen_string_literal: true

require 'test_helper'

class AiRoutingPolicyTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123'
    )
    @workspace = Workspace.create!(name: 'Test Workspace')
    @policy = AiRoutingPolicy.new(
      workspace: @workspace,
      name: 'Test Policy',
      primary_model: 'gpt-4',
      created_by: @user,
      updated_by: @user
    )
  end

  test "should be valid with required attributes" do
    assert @policy.valid?
  end

  test "should require name" do
    @policy.name = nil
    assert_not @policy.valid?
    assert_includes @policy.errors[:name], "can't be blank"
  end

  test "should require primary_model" do
    @policy.primary_model = nil
    assert_not @policy.valid?
    assert_includes @policy.errors[:primary_model], "can't be blank"
  end

  test "should validate cost thresholds" do
    @policy.cost_threshold_warning = 0.05
    @policy.cost_threshold_block = 0.02
    assert_not @policy.valid?
    assert_includes @policy.errors[:cost_threshold_block], 
                   "must be greater than warning threshold"
  end

  test "should handle fallback models as array" do
    @policy.fallback_models = ['gpt-3.5-turbo', 'claude-3-haiku']
    @policy.save!
    
    reloaded = AiRoutingPolicy.find(@policy.id)
    assert_equal ['gpt-3.5-turbo', 'claude-3-haiku'], reloaded.fallback_models
  end

  test "should estimate cost correctly" do
    cost = @policy.estimate_cost(1000, 500, 'gpt-4')
    expected_cost = (1.0 * 0.03) + (0.5 * 0.06) # 1K input + 0.5K output tokens
    assert_equal expected_cost, cost
  end

  test "should perform cost check correctly" do
    @policy.cost_threshold_warning = 0.05
    @policy.cost_threshold_block = 0.10
    
    # Low cost - should proceed
    result = @policy.cost_check(0.02)
    assert_equal :proceed, result[:action]
    
    # Warning threshold
    result = @policy.cost_check(0.07)
    assert_equal :warn, result[:action]
    
    # Block threshold
    result = @policy.cost_check(0.15)
    assert_equal :block, result[:action]
  end

  test "should get correct model for attempt" do
    @policy.fallback_models = ['gpt-3.5-turbo', 'claude-3-haiku']
    
    assert_equal 'gpt-4', @policy.get_model_for_attempt(1)
    assert_equal 'gpt-3.5-turbo', @policy.get_model_for_attempt(2)
    assert_equal 'claude-3-haiku', @policy.get_model_for_attempt(3)
  end

  test "should return ordered models correctly" do
    @policy.fallback_models = ['gpt-3.5-turbo', 'claude-3-haiku']
    expected = ['gpt-4', 'gpt-3.5-turbo', 'claude-3-haiku']
    assert_equal expected, @policy.ordered_models
  end

  test "should set default routing rules" do
    @policy.save!
    rules = @policy.effective_routing_rules
    
    assert_equal 3, rules['retry_attempts']
    assert_equal 5, rules['retry_delay']
    assert_equal 30, rules['timeout_seconds']
    assert_includes rules['failure_conditions'], 'timeout'
  end

  test "should set default fallbacks for gpt-4" do
    @policy.primary_model = 'gpt-4'
    @policy.save!
    
    assert_includes @policy.fallback_models, 'gpt-3.5-turbo'
  end
end