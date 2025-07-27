# frozen_string_literal: true

class CreateFallbackAiCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :fallback_ai_credentials do |t|
      t.references :ai_provider, foreign_key: true, null: false
      t.references :created_by, foreign_key: { to_table: :users }, null: false
      t.string :name, null: false                  # Admin-friendly name for this credential
      t.text :description                          # Optional description for admins
      t.text :encrypted_api_key                    # Encrypted API key
      t.text :encrypted_api_key_iv                 # Initialization vector for encryption
      t.string :preferred_model                    # e.g., "gpt-4", "claude-3-opus"
      t.decimal :temperature, precision: 3, scale: 2, default: 0.7
      t.integer :max_tokens, default: 4096
      t.string :response_format, default: 'text'   # text, json, markdown, html
      t.json :provider_config, default: {}         # Provider-specific settings
      t.text :system_prompt                        # Default system prompt for this credential
      t.boolean :active, default: true
      t.integer :priority, default: 0              # Lower number = higher priority
      
      # Usage limits and tracking
      t.integer :usage_limit                       # Total usage limit (nil = unlimited)
      t.integer :daily_limit                       # Daily usage limit (nil = unlimited)  
      t.integer :total_usage_count, default: 0     # Total times used
      t.datetime :expires_at                       # Optional expiration date
      t.datetime :last_used_at                     # When credential was last used
      
      # Admin configuration
      t.boolean :enabled_for_onboarding, default: true    # Show in onboarding flow
      t.boolean :enabled_for_trials, default: true        # Available for trial users
      t.text :onboarding_message                          # Custom message for onboarding
      
      t.timestamps
    end

    add_index :fallback_ai_credentials, [:ai_provider_id, :name], 
              unique: true, name: 'index_fallback_credentials_unique_name_per_provider'
    add_index :fallback_ai_credentials, [:active, :expires_at]
    add_index :fallback_ai_credentials, [:active, :priority]
    add_index :fallback_ai_credentials, :total_usage_count
    add_index :fallback_ai_credentials, :last_used_at
    add_index :fallback_ai_credentials, :enabled_for_onboarding
    add_index :fallback_ai_credentials, :enabled_for_trials
  end
end