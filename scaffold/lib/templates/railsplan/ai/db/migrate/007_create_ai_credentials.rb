# frozen_string_literal: true

class CreateAiCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_credentials do |t|
      t.references :workspace, foreign_key: true, null: false
      t.references :ai_provider, foreign_key: true, null: false
      t.string :name, null: false                  # User-friendly name for this credential
      t.text :encrypted_api_key                    # Encrypted API key
      t.text :encrypted_api_key_iv                 # Initialization vector for encryption
      t.string :preferred_model                    # e.g., "gpt-4", "claude-3-opus"
      t.decimal :temperature, precision: 3, scale: 2, default: 0.7
      t.integer :max_tokens, default: 4096
      t.string :response_format, default: 'text'   # text, json, markdown, html
      t.json :provider_config, default: {}         # Provider-specific settings
      t.text :system_prompt                        # Default system prompt for this credential
      t.boolean :active, default: true
      t.boolean :is_default, default: false        # Default credential for workspace+provider
      t.datetime :last_tested_at                   # When credential was last validated
      t.text :last_test_result                     # Result of last validation test
      t.datetime :last_used_at                     # When credential was last used
      t.integer :usage_count, default: 0           # Number of times used
      
      t.timestamps
    end

    add_index :ai_credentials, [:workspace_id, :ai_provider_id, :name], 
              unique: true, name: 'index_ai_credentials_unique_name_per_workspace_provider'
    add_index :ai_credentials, [:workspace_id, :is_default]
    add_index :ai_credentials, :active
    add_index :ai_credentials, :last_used_at
  end
end