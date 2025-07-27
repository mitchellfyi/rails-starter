# frozen_string_literal: true

class CreateMemberships < ActiveRecord::Migration[7.0]
  def change
    create_table :memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false
      t.references :invited_by, foreign_key: { to_table: :users }
      t.datetime :joined_at

      t.timestamps
    end

    add_index :memberships, [:workspace_id, :user_id], unique: true
    add_index :memberships, :user_id
    add_index :memberships, :role
    add_index :memberships, :invited_by_id
  end
end