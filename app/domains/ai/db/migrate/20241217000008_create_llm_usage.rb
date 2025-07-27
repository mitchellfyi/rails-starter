# frozen_string_literal: true

class CreateLlmUsage < ActiveRecord::Migration[7.0]
  def change
    create_table :llm_usage do |t|
      t.bigint :workspace_id, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.integer :prompt_tokens, default: 0
      t.integer :completion_tokens, default: 0
      t.integer :total_tokens, default: 0
      t.decimal :cost, precision: 10, scale: 6, default: 0.0
      t.date :date, null: false
      t.integer :request_count, default: 0
      
      t.timestamps
    end

    add_index :llm_usage, [:workspace_id, :date]
    add_index :llm_usage, [:workspace_id, :provider, :model, :date], 
              unique: true, name: 'index_llm_usage_unique'
    add_index :llm_usage, :date
    add_index :llm_usage, :cost
    
    add_foreign_key :llm_usage, :workspaces, column: :workspace_id
  end
end