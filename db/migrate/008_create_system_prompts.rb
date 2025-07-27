# frozen_string_literal: true

class CreateSystemPrompts < ActiveRecord::Migration[7.0]
  def change
    create_table :system_prompts do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.text :prompt_text, null: false
      t.string :status, null: false, default: 'draft'
      t.references :workspace, foreign_key: true, null: true # null means global
      t.references :created_by, foreign_key: { to_table: :users }, null: true
      t.string :version, default: '1.0.0'
      
      # Text fields for associations (SQLite doesn't support arrays)
      t.text :associated_roles # JSON string
      t.text :associated_functions # JSON string
      t.text :associated_agents # JSON string
      
      t.timestamps
    end

    # Unique constraints
    add_index :system_prompts, [:workspace_id, :name], unique: true
    add_index :system_prompts, [:workspace_id, :slug], unique: true
    
    # Performance indexes
    add_index :system_prompts, :status
    add_index :system_prompts, :version
    # workspace_id index already created by t.references
  end
end