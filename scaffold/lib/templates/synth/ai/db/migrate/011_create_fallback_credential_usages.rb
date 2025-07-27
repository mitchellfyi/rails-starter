# frozen_string_literal: true

class CreateFallbackCredentialUsages < ActiveRecord::Migration[7.0]
  def change
    create_table :fallback_credential_usages do |t|
      t.references :fallback_ai_credential, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.references :workspace, foreign_key: true, null: true
      t.date :date, null: false                    # Date of usage (for daily tracking)
      t.integer :usage_count, default: 0, null: false  # Number of API calls on this date
      t.datetime :last_used_at                     # Last time used on this date
      t.json :metadata, default: {}               # Additional usage metadata
      
      t.timestamps
    end

    # Ensure one record per credential/user/workspace/date combination
    add_index :fallback_credential_usages, 
              [:fallback_ai_credential_id, :user_id, :workspace_id, :date], 
              unique: true, 
              name: 'index_fallback_usage_unique_per_credential_user_workspace_date'
    
    # Indexes for common queries
    add_index :fallback_credential_usages, [:fallback_ai_credential_id, :date]
    add_index :fallback_credential_usages, [:user_id, :date]
    add_index :fallback_credential_usages, [:workspace_id, :date]
    add_index :fallback_credential_usages, :date
    add_index :fallback_credential_usages, :last_used_at
    add_index :fallback_credential_usages, :usage_count
  end
end