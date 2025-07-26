# frozen_string_literal: true

class AddFeedbackCommentToLlmOutputs < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_outputs, :feedback_comment, :text
    add_index :llm_outputs, :feedback_comment, where: "feedback_comment IS NOT NULL"
  end
end