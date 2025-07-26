# frozen_string_literal: true

class AddPromptExecutionToLlmOutputs < ActiveRecord::Migration[7.0]
  def change
    add_reference :llm_outputs, :prompt_execution, foreign_key: true, null: true
    add_index :llm_outputs, :prompt_execution_id
  end
end