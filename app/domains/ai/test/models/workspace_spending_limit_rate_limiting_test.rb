# frozen_string_literal: true

require 'test_helper'

class WorkspaceSpendingLimitRateLimitingTest < ActiveSupport::TestCase
  def setup
    @workspace = Workspace.create!(name: 'Test Workspace')
    @spending_limit = WorkspaceSpendingLimit.create!(
      workspace: @workspace,
      created_by: User.first || User.create!(email: 'test@example.com'),
      updated_by: User.first || User.create!(email: 'test@example.com'),
      rate_limit_enabled: true,
      requests_per_minute: 10,
      requests_per_hour: 100,
      requests_per_day: 1000,
      block_when_rate_limited: true
    )
  end

  test 'should validate rate limiting fields' do
    limit = WorkspaceSpendingLimit.new(
      workspace: @workspace,
      created_by: User.first,
      updated_by: User.first,
      requests_per_minute: -1
    )
    
    assert_not limit.valid?
    assert_includes limit.errors[:requests_per_minute], 'must be greater than 0'
  end

  test 'should check minute rate limiting' do
    # Add requests up to the limit
    9.times { @spending_limit.add_request! }
    
    assert_not @spending_limit.minute_exceeded?
    assert_not @spending_limit.would_be_rate_limited?
    
    # Add one more to exceed the limit
    @spending_limit.add_request!
    
    assert @spending_limit.minute_exceeded?
    assert @spending_limit.would_be_rate_limited?
  end

  test 'should reset counters after time periods' do
    # Add requests to exceed minute limit
    10.times { @spending_limit.add_request! }
    
    assert @spending_limit.minute_exceeded?
    
    # Simulate time passing (1 minute + 1 second)
    future_time = Time.current + 61.seconds
    Time.stub :current, future_time do
      assert_not @spending_limit.would_be_rate_limited?
    end
  end

  test 'should track different time period limits separately' do
    @spending_limit.update!(
      requests_per_minute: 2,
      requests_per_hour: 5,
      requests_per_day: 10
    )
    
    # Add 2 requests (at minute limit)
    2.times { @spending_limit.add_request! }
    
    assert @spending_limit.minute_exceeded?
    assert_not @spending_limit.hour_exceeded?
    assert_not @spending_limit.day_requests_exceeded?
    
    # Simulate minute passing, add 3 more (total 5, at hour limit)
    future_time = Time.current + 61.seconds
    Time.stub :current, future_time do
      3.times { @spending_limit.add_request! }
      
      assert_not @spending_limit.minute_exceeded?  # Reset after minute
      assert @spending_limit.hour_exceeded?
      assert_not @spending_limit.day_requests_exceeded?
    end
  end

  test 'should include rate limiting in spending summary' do
    5.times { @spending_limit.add_request! }
    
    summary = @spending_limit.spending_summary
    
    assert summary[:rate_limiting][:enabled]
    assert_equal 10, summary[:rate_limiting][:minute][:limit]
    assert_equal 5, summary[:rate_limiting][:minute][:current]
    assert_not summary[:rate_limiting][:minute][:exceeded]
  end

  test 'should allow at least one type of limit' do
    limit = WorkspaceSpendingLimit.new(
      workspace: @workspace,
      created_by: User.first,
      updated_by: User.first
    )
    
    assert_not limit.valid?
    assert_includes limit.errors[:base], 'At least one spending or rate limit must be set'
    
    # Adding a rate limit should make it valid
    limit.requests_per_hour = 100
    assert limit.valid?
  end
end