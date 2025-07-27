# frozen_string_literal: true

class AddWorkspaceAndCredentialToLlmOutputs < ActiveRecord::Migration[7.0]
  def change
    add_reference :llm_outputs, :ai_credential, foreign_key: true, null: true
    add_reference :llm_outputs, :workspace, foreign_key: true, null: true
    
    add_index :llm_outputs, :ai_credential_id
    add_index :llm_outputs, :workspace_id
  end
end