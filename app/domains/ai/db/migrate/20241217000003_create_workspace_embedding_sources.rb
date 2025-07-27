# frozen_string_literal: true

class CreateWorkspaceEmbeddingSources < ActiveRecord::Migration[7.1]
  def change
    create_table :workspace_embedding_sources do |t|
      t.string :name, null: false
      t.text :description
      t.string :source_type, null: false # 'dataset', 'context_fetcher', 'semantic_memory', 'external_api', 'manual'
      t.string :status, null: false, default: 'inactive' # 'active', 'inactive', 'processing', 'error'
      t.json :config, default: {}
      t.datetime :last_tested_at
      
      t.references :workspace, null: false, foreign_key: true
      t.references :ai_dataset, null: true, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      
      t.timestamps
    end
    
    add_index :workspace_embedding_sources, :source_type
    add_index :workspace_embedding_sources, :status
    add_index :workspace_embedding_sources, [:workspace_id, :status]
    add_index :workspace_embedding_sources, [:workspace_id, :source_type]
    add_index :workspace_embedding_sources, :last_tested_at
  end
end