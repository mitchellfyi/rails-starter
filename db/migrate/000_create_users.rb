# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :first_name
      t.string :last_name
      t.datetime :confirmed_at
      t.datetime :last_sign_in_at
      
      t.timestamps
    end
    
    add_index :users, :email, unique: true
  end
end