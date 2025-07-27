class CreatePromptExecutions < ActiveRecord::Migration[7.0]
  def change
    create_table :prompt_executions do |t|
      t.references :prompt_template, null: true, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :workspace, null: true, foreign_key: true
      t.references :ai_credential, null: true, foreign_key: true
      t.json :input_context, default: {}
      t.text :rendered_prompt
      t.string :status, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at
      t.text :output
      t.text :error_message
      t.string :model_used
      t.integer :tokens_used
      t.boolean :playground_session, default: false
      t.json :session_data, default: {}

      t.timestamps
    end

    add_index :prompt_executions, [:workspace_id, :created_at]
    add_index :prompt_executions, [:user_id, :created_at]
    add_index :prompt_executions, :status
    add_index :prompt_executions, :ai_credential_id
    add_index :prompt_executions, :playground_session
  end
end