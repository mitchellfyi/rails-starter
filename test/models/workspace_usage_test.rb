# frozen_string_literal: true

require 'test_helper'

class WorkspaceUsageTest < ActiveSupport::TestCase
  def setup
    @workspace = Workspace.create!(
      name: 'Test Workspace',
      monthly_ai_credit: 100.0,
      current_month_usage: 25.0
    )
  end

  test 'should calculate remaining monthly credit' do
    assert_equal 75.0, @workspace.remaining_monthly_credit
  end

  test 'should detect credit exhaustion' do
    @workspace.update!(current_month_usage: 100.0)
    assert @workspace.credit_exhausted?

    @workspace.update!(current_month_usage: 99.0)
    assert_not @workspace.credit_exhausted?
  end

  test 'should calculate usage percentage' do
    assert_equal 25.0, @workspace.usage_percentage
  end

  test 'should detect if cost would exceed credit' do
    assert_not @workspace.would_exceed_credit?(50.0)
    assert @workspace.would_exceed_credit?(80.0)
  end

  test 'should add usage and reset monthly if needed' do
    # Mock current date to be next month
    Date.stub :current, Date.current + 1.month do
      @workspace.add_usage!(10.0)
      
      # Should reset usage for new month
      assert_equal 10.0, @workspace.current_month_usage
    end
  end

  test 'should return usage summary' do
    summary = @workspace.usage_summary
    
    assert_equal 100.0, summary[:monthly_credit]
    assert_equal 25.0, summary[:current_usage]
    assert_equal 75.0, summary[:remaining_credit]
    assert_equal 25.0, summary[:usage_percentage]
    assert_equal false, summary[:credit_exhausted]
    assert_equal false, summary[:overage_billing_enabled]
  end

  test 'should set default values on initialization' do
    new_workspace = Workspace.new(name: 'New Workspace')
    
    assert_equal 10.0, new_workspace.monthly_ai_credit
    assert_equal 0.0, new_workspace.current_month_usage
    assert_equal Date.current.beginning_of_month, new_workspace.usage_reset_date
    assert_equal false, new_workspace.overage_billing_enabled
  end

  test 'should reset monthly usage when month changes' do
    # Set usage to last month
    @workspace.update!(
      usage_reset_date: Date.current.beginning_of_month - 1.month,
      current_month_usage: 50.0
    )

    @workspace.reset_monthly_usage_if_needed!
    @workspace.reload
    
    assert_equal 0.0, @workspace.current_month_usage
    assert_equal Date.current.beginning_of_month, @workspace.usage_reset_date
  end
end