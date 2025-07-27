# frozen_string_literal: true

class CreateImpersonations < ActiveRecord::Migration[7.1]
  def change
    create_table :impersonations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :impersonator, null: false, foreign_key: { to_table: :users }
      t.references :impersonated_user, null: false, foreign_key: { to_table: :users }
      t.text :reason, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.string :ended_by, limit: 100
      
      t.timestamps
    end
    
    add_index :impersonations, [:workspace_id, :impersonator_id, :ended_at], 
              name: 'index_impersonations_on_workspace_impersonator_ended'
    add_index :impersonations, [:workspace_id, :impersonated_user_id, :ended_at],
              name: 'index_impersonations_on_workspace_impersonated_ended'
    add_index :impersonations, :started_at
  end
end