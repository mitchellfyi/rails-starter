# frozen_string_literal: true

class AddMonthlyCreditsToWorkspaces < ActiveRecord::Migration[7.0]
  def change
    add_column :workspaces, :monthly_ai_credit, :decimal, precision: 10, scale: 6, default: 10.0
    add_column :workspaces, :current_month_usage, :decimal, precision: 10, scale: 6, default: 0.0
    add_column :workspaces, :usage_reset_date, :date
    add_column :workspaces, :overage_billing_enabled, :boolean, default: false
    add_column :workspaces, :stripe_meter_id, :string
    
    add_index :workspaces, :usage_reset_date
    add_index :workspaces, :overage_billing_enabled
  end
end