# frozen_string_literal: true

class AddTwoFactorAuthToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :encrypted_two_factor_secret, :text
    add_column :users, :encrypted_two_factor_secret_iv, :text
    add_column :users, :backup_codes, :text # Store as JSON
    
    add_index :users, :encrypted_two_factor_secret_iv
  end
end
