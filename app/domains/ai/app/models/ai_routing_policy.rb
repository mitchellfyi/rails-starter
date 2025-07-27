# frozen_string_literal: true

class AiRoutingPolicy < ApplicationRecord
  belongs_to :workspace
  belongs_to :created_by, class_name: 'User'
  belongs_to :updated_by, class_name: 'User'

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :primary_model, presence: true
  validates :cost_threshold_warning, presence: true, numericality: { greater_than: 0 }
  validates :cost_threshold_block, presence: true, numericality: { greater_than: 0 }
  validate :cost_threshold_block_greater_than_warning

  # Available models with their approximate costs per 1K tokens
  MODEL_COSTS = {
    'gpt-4' => { input: 0.03, output: 0.06 },
    'gpt-4-turbo' => { input: 0.01, output: 0.03 },
    'gpt-4o' => { input: 0.005, output: 0.015 },
    'gpt-3.5-turbo' => { input: 0.0015, output: 0.002 },
    'claude-3-opus' => { input: 0.015, output: 0.075 },
    'claude-3-sonnet' => { input: 0.003, output: 0.015 },
    'claude-3-haiku' => { input: 0.00025, output: 0.00125 }
  }.freeze

  DEFAULT_ROUTING_RULES = {
    'retry_attempts' => 3,
    'retry_delay' => 5,
    'timeout_seconds' => 30,
    'failure_conditions' => ['timeout', 'rate_limit', 'server_error']
  }.freeze

  DEFAULT_COST_RULES = {
    'calculate_before_request' => true,
    'track_actual_usage' => true,
    'notification_threshold_multiplier' => 0.8
  }.freeze

  after_initialize :set_defaults, if: :new_record?

  scope :enabled, -> { where(enabled: true) }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) }

  def fallback_models
    return [] unless super.present?
    JSON.parse(super)
  rescue JSON::ParserError
    []
  end

  def fallback_models=(value)
    super(value.is_a?(Array) ? value.to_json : value)
  end

  def routing_rules
    @routing_rules ||= (super.present? ? JSON.parse(super) : {}).with_indifferent_access
  rescue JSON::ParserError
    DEFAULT_ROUTING_RULES.with_indifferent_access
  end

  def routing_rules=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
    @routing_rules = nil
  end

  def cost_rules
    @cost_rules ||= (super.present? ? JSON.parse(super) : {}).with_indifferent_access
  rescue JSON::ParserError
    DEFAULT_COST_RULES.with_indifferent_access
  end

  def cost_rules=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
    @cost_rules = nil
  end

  def effective_routing_rules
    DEFAULT_ROUTING_RULES.merge(routing_rules)
  end

  def effective_cost_rules
    DEFAULT_COST_RULES.merge(cost_rules)
  end

  # Get the next model to try based on current attempt
  def get_model_for_attempt(attempt_number)
    return primary_model if attempt_number == 1
    
    fallback_index = attempt_number - 2
    return fallback_models[fallback_index] if fallback_models[fallback_index]
    
    # If we've exhausted fallbacks, return the cheapest available model
    cheapest_model
  end

  # Calculate estimated cost for a request
  def estimate_cost(input_tokens, max_output_tokens, model = nil)
    target_model = model || primary_model
    costs = MODEL_COSTS[target_model]
    
    return 0.0 unless costs
    
    input_cost = (input_tokens / 1000.0) * costs[:input]
    output_cost = (max_output_tokens / 1000.0) * costs[:output]
    
    input_cost + output_cost
  end

  # Check if cost exceeds thresholds
  def cost_check(estimated_cost)
    if estimated_cost >= cost_threshold_block
      { action: :block, reason: "Cost #{estimated_cost} exceeds block threshold #{cost_threshold_block}" }
    elsif estimated_cost >= cost_threshold_warning
      { action: :warn, reason: "Cost #{estimated_cost} exceeds warning threshold #{cost_threshold_warning}" }
    else
      { action: :proceed, reason: "Cost #{estimated_cost} within limits" }
    end
  end

  # Determine if we should retry based on the error and rules
  def should_retry?(error, attempt_number)
    return false if attempt_number >= effective_routing_rules['retry_attempts']
    return false unless effective_routing_rules['failure_conditions'].present?
    
    error_type = classify_error(error)
    effective_routing_rules['failure_conditions'].include?(error_type)
  end

  # Get all models ordered by preference (primary first, then fallbacks)
  def ordered_models
    [primary_model] + fallback_models
  end

  # Get model summary for display
  def model_summary
    {
      primary: primary_model,
      fallbacks: fallback_models,
      total_models: ordered_models.length,
      estimated_cost_range: cost_range
    }
  end

  private

  def set_defaults
    self.routing_rules ||= DEFAULT_ROUTING_RULES
    self.cost_rules ||= DEFAULT_COST_RULES
    self.fallback_models ||= default_fallbacks_for_model(primary_model) if primary_model
  end

  def cost_threshold_block_greater_than_warning
    return unless cost_threshold_warning && cost_threshold_block
    
    if cost_threshold_block <= cost_threshold_warning
      errors.add(:cost_threshold_block, 'must be greater than warning threshold')
    end
  end

  def default_fallbacks_for_model(model)
    case model
    when 'gpt-4', 'gpt-4-turbo', 'gpt-4o'
      ['gpt-3.5-turbo']
    when 'claude-3-opus'
      ['claude-3-sonnet', 'claude-3-haiku']
    when 'claude-3-sonnet'
      ['claude-3-haiku']
    else
      []
    end
  end

  def cheapest_model
    MODEL_COSTS.min_by { |model, costs| costs[:input] + costs[:output] }&.first || 'gpt-3.5-turbo'
  end

  def classify_error(error)
    case error.class.name
    when /timeout/i
      'timeout'
    when /rate/i
      'rate_limit'
    when /server/i, /5\d\d/
      'server_error'
    when /authentication/i, /authorization/i
      'auth_error'
    else
      'unknown_error'
    end
  end

  def cost_range
    models = ordered_models.select { |m| MODEL_COSTS[m] }
    return { min: 0, max: 0 } if models.empty?
    
    costs = models.map { |m| MODEL_COSTS[m][:input] + MODEL_COSTS[m][:output] }
    { min: costs.min, max: costs.max }
  end
end