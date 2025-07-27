# frozen_string_literal: true

class CreateAiDatasets < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_datasets do |t|
      t.string :name, null: false
      t.text :description
      t.string :dataset_type, null: false # 'embedding', 'fine-tune'
      t.string :processed_status, null: false, default: 'pending' # 'pending', 'processing', 'completed', 'failed'
      t.datetime :processed_at
      t.text :error_message
      t.json :metadata, default: {}
      
      t.references :workspace, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      
      t.timestamps
    end
    
    add_index :ai_datasets, :dataset_type
    add_index :ai_datasets, :processed_status
    add_index :ai_datasets, [:workspace_id, :dataset_type]
    add_index :ai_datasets, [:workspace_id, :processed_status]
    add_index :ai_datasets, :processed_at
  end
end