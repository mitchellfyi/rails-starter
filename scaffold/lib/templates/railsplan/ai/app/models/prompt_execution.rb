# frozen_string_literal: true

class PromptExecution < ApplicationRecord
  belongs_to :prompt_template
  belongs_to :user, optional: true
  belongs_to :workspace, optional: true

  validates :input_context, presence: true
  validates :rendered_prompt, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed preview] }

  scope :successful, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :preview, -> { where(status: 'preview') }

  def success?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def preview?
    status == 'preview'
  end

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  # Execute this prompt with LLM
  def execute_with_llm!(model_name = nil)
    return if status != 'pending'

    update!(
      status: 'processing',
      started_at: Time.current,
      model_used: model_name || 'gpt-4'
    )

    begin
      # Create corresponding LLMOutput for backward compatibility
      llm_output = LLMOutput.create!(
        template_name: prompt_template.slug,
        model_name: model_used,
        context: input_context,
        format: prompt_template.output_format,
        prompt: rendered_prompt,
        status: 'processing',
        job_id: SecureRandom.uuid,
        user: user
      )

      # Queue LLM job
      LLMJob.perform_later(
        template: rendered_prompt,
        model: model_used,
        context: input_context,
        format: prompt_template.output_format,
        user_id: user_id,
        execution_id: id,
        output_id: llm_output.id
      )

    rescue => error
      update!(
        status: 'failed',
        error_message: error.message,
        completed_at: Time.current
      )
      raise error
    end
  end
end