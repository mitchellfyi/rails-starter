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
      
      # Arrays for associations with roles, functions, agents
      t.string :associated_roles, array: true, default: []
      t.string :associated_functions, array: true, default: []
      t.string :associated_agents, array: true, default: []
      
      t.timestamps
    end

    # Unique constraints
    add_index :system_prompts, [:workspace_id, :name], unique: true
    add_index :system_prompts, [:workspace_id, :slug], unique: true
    
    # Performance indexes
    add_index :system_prompts, :status
    add_index :system_prompts, :version
    add_index :system_prompts, :workspace_id
    add_index :system_prompts, :associated_roles, using: 'gin'
    add_index :system_prompts, :associated_functions, using: 'gin'
    add_index :system_prompts, :associated_agents, using: 'gin'
  end
end