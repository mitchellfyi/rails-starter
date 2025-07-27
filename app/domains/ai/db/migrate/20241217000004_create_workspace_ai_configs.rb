# frozen_string_literal: true

class CreateWorkspaceAiConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :workspace_ai_configs do |t|
      t.text :instructions
      t.boolean :rag_enabled, default: true, null: false
      t.string :embedding_model, default: 'text-embedding-ada-002', null: false
      t.string :chat_model, default: 'gpt-4', null: false
      t.decimal :temperature, precision: 3, scale: 2, default: 0.7, null: false
      t.integer :max_tokens, default: 4096, null: false
      t.json :rag_config, default: {}
      t.json :model_config, default: {}
      t.json :tools_config, default: {}
      
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      
      t.timestamps
    end
    
    add_index :workspace_ai_configs, :rag_enabled
    add_index :workspace_ai_configs, :embedding_model
    add_index :workspace_ai_configs, :chat_model
  end
end