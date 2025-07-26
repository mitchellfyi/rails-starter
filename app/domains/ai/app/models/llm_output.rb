# frozen_string_literal: true

class LLMOutput < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :agent, optional: true
  belongs_to :prompt_template, foreign_key: :template_name, primary_key: :slug, optional: true
  belongs_to :prompt_execution, optional: true

  validates :template_name, presence: true
  validates :model_name, presence: true
  validates :format, presence: true, inclusion: { in: %w[text json markdown html] }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  validate :raw_response_required_for_completed_status
  validates :job_id, presence: true

  enum feedback: {
    none: 0,
    thumbs_up: 1,
    thumbs_down: 2
  }

  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_template, ->(template) { where(template_name: template) }
  scope :by_model, ->(model) { where(model_name: model) }

  # Re-run the same job with identical parameters
  def re_run!
    LLMJob.perform_later(
      template: template_name,
      model: model_name,
      context: context,
      format: format,
      user_id: user_id,
      agent_id: agent_id
    )
  end

  # Regenerate with potentially modified context
  def regenerate!(new_context: nil, new_model: nil)
    context_to_use = new_context || context
    model_to_use = new_model || model_name

    LLMJob.perform_later(
      template: template_name,
      model: model_to_use,
      context: context_to_use,
      format: format,
      user_id: user_id,
      agent_id: agent_id
    )
  end

  # Set feedback and optionally trigger actions
  def set_feedback!(feedback_type, user: nil, comment: nil)
    update!(
      feedback: feedback_type, 
      feedback_at: Time.current,
      feedback_comment: comment
    )
    
    # Log the feedback for analytics
    Rails.logger.info "LLM output feedback received", {
      output_id: id,
      feedback: feedback_type,
      user_id: user&.id,
      template_name: template_name,
      model_name: model_name,
      has_comment: comment.present?
    }

    # Could trigger follow-up actions based on feedback
    case feedback_type
    when 'thumbs_down'
      # Could automatically trigger a regeneration or notify admins
      Rails.logger.info "Negative feedback received for LLM output #{id}", { comment: comment }
    when 'thumbs_up'
      # Could be used for training data or quality metrics
      Rails.logger.info "Positive feedback received for LLM output #{id}", { comment: comment }
    end
  end

  def success?
    status == 'completed' && raw_response.present?
  end

  def failed?
    status == 'failed'
  end

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def has_feedback_comment?
    feedback_comment.present?
  end

  # Format the output based on the specified format
  def formatted_output
    case format
    when 'json'
      begin
        JSON.pretty_generate(JSON.parse(parsed_output))
      rescue JSON::ParserError
        parsed_output
      end
    when 'markdown', 'html'
      parsed_output
    else
      parsed_output
    end
  end

  # Calculate token usage (placeholder - would integrate with actual LLM APIs)
  def estimated_token_count
    return 0 unless raw_response
    
    # Simple estimation: ~4 characters per token for English text
    raw_response.length / 4
  end
end