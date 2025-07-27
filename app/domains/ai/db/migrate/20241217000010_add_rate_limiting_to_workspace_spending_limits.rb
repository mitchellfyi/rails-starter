# frozen_string_literal: true

class AddRateLimitingToWorkspaceSpendingLimits < ActiveRecord::Migration[7.0]
  def change
    add_column :workspace_spending_limits, :rate_limit_enabled, :boolean, default: false
    add_column :workspace_spending_limits, :requests_per_minute, :integer
    add_column :workspace_spending_limits, :requests_per_hour, :integer
    add_column :workspace_spending_limits, :requests_per_day, :integer
    add_column :workspace_spending_limits, :current_minute_requests, :integer, default: 0
    add_column :workspace_spending_limits, :current_hour_requests, :integer, default: 0
    add_column :workspace_spending_limits, :current_day_requests, :integer, default: 0
    add_column :workspace_spending_limits, :last_request_time, :datetime
    add_column :workspace_spending_limits, :block_when_rate_limited, :boolean, default: true
    
    add_index :workspace_spending_limits, :rate_limit_enabled
    add_index :workspace_spending_limits, :last_request_time
  end
end