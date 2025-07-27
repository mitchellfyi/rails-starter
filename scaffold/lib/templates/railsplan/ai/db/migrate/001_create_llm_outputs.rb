# frozen_string_literal: true

class CreateLLMOutputs < ActiveRecord::Migration[7.0]
  def change
    create_table :llm_outputs do |t|
      t.string :template_name, null: false
      t.string :model_name, null: false
      t.json :context, default: {}
      t.string :format, null: false, default: 'text'
      t.text :prompt
      t.text :raw_response
      t.text :parsed_output
      t.string :status, null: false, default: 'pending'
      t.string :job_id, null: false
      t.integer :feedback, default: 0
      t.timestamp :feedback_at
      t.references :user, null: true, foreign_key: true
      t.references :agent, null: true, foreign_key: false # May not have agent table
      t.timestamps

      t.index [:template_name]
      t.index [:model_name]
      t.index [:status]
      t.index [:user_id]
      t.index [:job_id]
      t.index [:created_at]
      t.index [:feedback]
    end
  end
end