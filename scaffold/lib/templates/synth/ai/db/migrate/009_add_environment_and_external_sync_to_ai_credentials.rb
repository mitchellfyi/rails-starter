# frozen_string_literal: true

class AddEnvironmentAndExternalSyncToAiCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_credentials, :environment_source, :string
    add_column :ai_credentials, :imported_at, :datetime
    add_reference :ai_credentials, :imported_by, null: true, foreign_key: { to_table: :users }
    
    # Vault integration fields
    add_column :ai_credentials, :vault_secret_key, :string
    add_column :ai_credentials, :vault_synced_at, :datetime
    
    # Doppler integration fields
    add_column :ai_credentials, :doppler_secret_name, :string
    add_column :ai_credentials, :doppler_synced_at, :datetime
    
    # 1Password integration fields
    add_column :ai_credentials, :onepassword_item_id, :string
    add_column :ai_credentials, :onepassword_synced_at, :datetime
    
    add_index :ai_credentials, :environment_source
    add_index :ai_credentials, :vault_secret_key
    add_index :ai_credentials, :doppler_secret_name
    add_index :ai_credentials, :onepassword_item_id
  end
end