# frozen_string_literal: true

class CreateWorkspaceSpendingLimits < ActiveRecord::Migration[7.0]
  def change
    create_table :workspace_spending_limits do |t|
      t.references :workspace, null: false, foreign_key: true
      t.decimal :daily_limit, precision: 10, scale: 4
      t.decimal :weekly_limit, precision: 10, scale: 4
      t.decimal :monthly_limit, precision: 10, scale: 4
      t.decimal :current_daily_spend, precision: 10, scale: 4, default: 0.0
      t.decimal :current_weekly_spend, precision: 10, scale: 4, default: 0.0
      t.decimal :current_monthly_spend, precision: 10, scale: 4, default: 0.0
      t.date :last_reset_date
      t.boolean :enabled, default: true
      t.boolean :block_when_exceeded, default: false
      t.text :notification_emails # JSON array of emails to notify
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.timestamps

      t.index [:workspace_id], unique: true
      t.index [:enabled]
    end
  end
end