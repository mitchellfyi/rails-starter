# frozen_string_literal: true

class AddFallbackSupportToAiCredentials < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_credentials, :is_fallback, :boolean, default: false, null: false
    add_column :ai_credentials, :fallback_usage_limit, :integer
    add_column :ai_credentials, :fallback_usage_count, :integer, default: 0, null: false
    add_column :ai_credentials, :expires_at, :datetime
    add_column :ai_credentials, :onboarding_message, :text
    add_column :ai_credentials, :enabled_for_trials, :boolean, default: true, null: false
    
    add_index :ai_credentials, :is_fallback
    add_index :ai_credentials, [:is_fallback, :active, :expires_at]
    add_index :ai_credentials, :fallback_usage_count
  end
end