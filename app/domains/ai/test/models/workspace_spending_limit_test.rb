# frozen_string_literal: true

require 'test_helper'

class WorkspaceSpendingLimitTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123'
    )
    @workspace = Workspace.create!(name: 'Test Workspace')
    @spending_limit = WorkspaceSpendingLimit.new(
      workspace: @workspace,
      daily_limit: 10.00,
      weekly_limit: 50.00,
      monthly_limit: 200.00,
      created_by: @user,
      updated_by: @user
    )
  end

  test "should be valid with required attributes" do
    assert @spending_limit.valid?
  end

  test "should require at least one limit" do
    @spending_limit.daily_limit = nil
    @spending_limit.weekly_limit = nil
    @spending_limit.monthly_limit = nil
    
    assert_not @spending_limit.valid?
    assert_includes @spending_limit.errors[:base], "At least one spending limit must be set"
  end

  test "should handle notification emails as array" do
    @spending_limit.notification_emails = ['admin@example.com', 'billing@example.com']
    @spending_limit.save!
    
    reloaded = WorkspaceSpendingLimit.find(@spending_limit.id)
    assert_equal ['admin@example.com', 'billing@example.com'], reloaded.notification_emails
  end

  test "should check if limits are exceeded" do
    @spending_limit.current_daily_spend = 12.00
    assert @spending_limit.daily_exceeded?
    assert @spending_limit.exceeded?
  end

  test "should calculate remaining budget correctly" do
    @spending_limit.current_daily_spend = 3.00
    @spending_limit.current_weekly_spend = 15.00
    @spending_limit.current_monthly_spend = 75.00
    
    assert_equal 7.00, @spending_limit.remaining_daily_budget
    assert_equal 35.00, @spending_limit.remaining_weekly_budget
    assert_equal 125.00, @spending_limit.remaining_monthly_budget
    assert_equal 7.00, @spending_limit.remaining_budget # Most restrictive
  end

  test "should check if cost would exceed limits" do
    @spending_limit.current_daily_spend = 8.00
    @spending_limit.save!
    
    assert_not @spending_limit.would_exceed?(1.00)
    assert @spending_limit.would_exceed?(3.00)
  end

  test "should add spending correctly" do
    @spending_limit.save!
    initial_daily = @spending_limit.current_daily_spend
    
    @spending_limit.add_spending!(5.00)
    
    assert_equal initial_daily + 5.00, @spending_limit.reload.current_daily_spend
    assert_equal 5.00, @spending_limit.current_weekly_spend
    assert_equal 5.00, @spending_limit.current_monthly_spend
  end

  test "should provide spending summary" do
    @spending_limit.current_daily_spend = 5.00
    @spending_limit.current_weekly_spend = 20.00
    @spending_limit.current_monthly_spend = 80.00
    
    summary = @spending_limit.spending_summary
    
    assert_equal 10.00, summary[:daily][:limit]
    assert_equal 5.00, summary[:daily][:current]
    assert_equal 5.00, summary[:daily][:remaining]
    assert_not summary[:daily][:exceeded]
    
    assert_not summary[:overall_exceeded]
  end

  test "should find or create for workspace" do
    limit = WorkspaceSpendingLimit.for_workspace(@workspace)
    assert limit.persisted?
    assert_equal @workspace, limit.workspace
    
    # Should find existing on second call
    same_limit = WorkspaceSpendingLimit.for_workspace(@workspace)
    assert_equal limit.id, same_limit.id
  end
end