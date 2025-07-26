# frozen_string_literal: true

class CreatePromptExecutions < ActiveRecord::Migration[7.0]
  def change
    create_table :prompt_executions do |t|
      t.references :prompt_template, null: false, foreign_key: true
      t.references :user, foreign_key: true, null: true
      t.references :workspace, foreign_key: true, null: true
      
      t.json :input_context, null: false
      t.text :rendered_prompt, null: false
      t.text :output
      t.text :error_message
      t.string :status, null: false, default: 'pending'
      t.string :model_used
      t.integer :tokens_used
      t.datetime :started_at
      t.datetime :completed_at
      
      t.timestamps
    end

    add_index :prompt_executions, :status
    add_index :prompt_executions, :created_at
    add_index :prompt_executions, [:prompt_template_id, :created_at]
  end
end