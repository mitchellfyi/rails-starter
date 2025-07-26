# frozen_string_literal: true

class CreateWorkspaceRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :workspace_roles do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false, limit: 50
      t.string :display_name, null: false, limit: 100
      t.text :description
      t.json :permissions, default: {}
      t.integer :priority, default: 0
      t.boolean :system_role, default: false, null: false
      
      t.timestamps
    end
    
    add_index :workspace_roles, [:workspace_id, :name], unique: true
    add_index :workspace_roles, [:workspace_id, :priority]
  end
end