# frozen_string_literal: true

class CreateInvitations < ActiveRecord::Migration[7.0]
  def change
    create_table :invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :email, null: false
      t.string :role, null: false
      t.string :token, null: false
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.datetime :accepted_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, [:workspace_id, :email], unique: true, where: 'accepted_at IS NULL'
    add_index :invitations, :email
    add_index :invitations, :invited_by_id
    add_index :invitations, :expires_at
  end
end