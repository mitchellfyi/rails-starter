# frozen_string_literal: true

class AddCostTrackingToLlmOutputs < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_outputs, :estimated_cost, :decimal, precision: 10, scale: 6
    add_column :llm_outputs, :actual_cost, :decimal, precision: 10, scale: 6
    add_column :llm_outputs, :input_tokens, :integer
    add_column :llm_outputs, :output_tokens, :integer
    add_column :llm_outputs, :routing_decision, :text # JSON for routing info
    add_column :llm_outputs, :cost_warning_triggered, :boolean, default: false
    add_column :llm_outputs, :workspace_id, :bigint
    
    add_index :llm_outputs, :estimated_cost
    add_index :llm_outputs, :actual_cost
    add_index :llm_outputs, :workspace_id
    add_index :llm_outputs, :cost_warning_triggered
    add_index :llm_outputs, [:workspace_id, :created_at]
    
    add_foreign_key :llm_outputs, :workspaces, column: :workspace_id
  end
end