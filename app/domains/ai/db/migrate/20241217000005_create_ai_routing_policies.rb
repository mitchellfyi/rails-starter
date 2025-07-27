# frozen_string_literal: true

class CreateAiRoutingPolicies < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_routing_policies do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :primary_model, null: false
      t.text :fallback_models # JSON array of fallback models in order
      t.decimal :cost_threshold_warning, precision: 10, scale: 4, default: 0.01
      t.decimal :cost_threshold_block, precision: 10, scale: 4, default: 0.10
      t.boolean :enabled, default: true
      t.text :routing_rules # JSON configuration for routing rules
      t.text :cost_rules # JSON configuration for cost rules
      t.text :description
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.timestamps

      t.index [:workspace_id, :name], unique: true
      t.index [:workspace_id, :enabled]
      t.index [:primary_model]
    end
  end
end