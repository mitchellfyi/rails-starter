# frozen_string_literal: true

class LLMOutput < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :agent, optional: true
  belongs_to :workspace, optional: true
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
  scope :with_cost_warnings, -> { where(cost_warning_triggered: true) }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  scope :high_cost, ->(threshold) { where('estimated_cost > ? OR actual_cost > ?', threshold, threshold) }

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

  # Get routing decision details
  def routing_decision
    return {} unless super.present?
    JSON.parse(super)
  rescue JSON::ParserError
    {}
  end

  def routing_decision=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  # Get the actual cost or estimated cost
  def effective_cost
    actual_cost || estimated_cost || 0.0
  end

  # Check if this request had cost issues
  def cost_issue?
    cost_warning_triggered? || effective_cost > 0.05
  end

  # Update actual cost and workspace spending
  def update_actual_cost!(cost, input_tokens: nil, output_tokens: nil)
    update!(
      actual_cost: cost,
      input_tokens: input_tokens,
      output_tokens: output_tokens
    )

    # Update workspace spending if workspace is present
    if workspace&.workspace_spending_limit
      workspace.workspace_spending_limit.add_spending!(cost)
    end

    # Also track in workspace monthly usage for credit/billing purposes
    workspace&.add_usage!(cost)
  end

  # Format routing decision for display
  def routing_summary
    decision = routing_decision
    return "Direct request" if decision.empty?

    parts = []
    parts << "Primary: #{decision['primary_model']}" if decision['primary_model']
    parts << "Attempts: #{decision['total_attempts']}" if decision['total_attempts']
    parts << "Final: #{decision['final_model']}" if decision['final_model']
    parts << "Cost warning" if cost_warning_triggered?
    
    parts.join(", ")
  end
end