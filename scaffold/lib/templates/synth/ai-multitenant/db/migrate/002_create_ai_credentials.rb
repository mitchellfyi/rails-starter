class CreateAiCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_credentials do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :ai_provider, null: false, foreign_key: true
      t.string :name, null: false
      t.text :encrypted_api_key, null: false
      t.string :preferred_model, null: false
      t.decimal :temperature, precision: 3, scale: 2, default: 0.7
      t.integer :max_tokens, default: 4096
      t.text :system_prompt
      t.text :provider_config, default: '{}'
      t.boolean :is_default, default: false
      t.boolean :active, default: true
      t.datetime :last_used_at
      t.datetime :last_tested_at

      t.timestamps
    end

    add_index :ai_credentials, [:workspace_id, :ai_provider_id], name: 'index_ai_credentials_on_workspace_and_provider'
    add_index :ai_credentials, [:workspace_id, :ai_provider_id, :is_default], name: 'index_ai_credentials_on_default'
    add_index :ai_credentials, :active
    add_index :ai_credentials, :last_used_at
  end
end