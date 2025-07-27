class CreateLlmOutputs < ActiveRecord::Migration[7.0]
  def change
    create_table :llm_outputs do |t|
      t.references :user, null: true, foreign_key: true
      t.references :agent, null: true, foreign_key: true
      t.references :workspace, null: true, foreign_key: true
      t.references :ai_credential, null: true, foreign_key: true
      t.references :prompt_execution, null: true, foreign_key: true
      t.string :template_name, null: false
      t.string :model_name, null: false
      t.json :context, default: {}
      t.string :format, default: 'text'
      t.text :prompt
      t.text :raw_response
      t.text :parsed_output
      t.string :status, default: 'pending'
      t.integer :feedback, default: 0
      t.string :job_id
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :llm_outputs, [:user_id, :created_at]
    add_index :llm_outputs, [:workspace_id, :created_at]
    add_index :llm_outputs, :status
    add_index :llm_outputs, :feedback
    add_index :llm_outputs, :job_id
    add_index :llm_outputs, :ai_credential_id
  end
end