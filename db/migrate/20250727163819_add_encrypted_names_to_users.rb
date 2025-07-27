# frozen_string_literal: true

class AddEncryptedNamesToUsers < ActiveRecord::Migration[7.1]
  def change
    # Add encrypted versions of sensitive fields
    add_column :users, :encrypted_first_name, :text
    add_column :users, :encrypted_first_name_iv, :text
    add_column :users, :encrypted_last_name, :text
    add_column :users, :encrypted_last_name_iv, :text
    
    # Add indexes for performance
    add_index :users, :encrypted_first_name_iv
    add_index :users, :encrypted_last_name_iv
  end
end
