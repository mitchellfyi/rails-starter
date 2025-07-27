# frozen_string_literal: true

class Agent < ApplicationRecord
  belongs_to :workspace
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  belongs_to :prompt_template, optional: true
  
  has_many :llm_outputs, dependent: :destroy
  has_many :prompt_executions, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :slug, presence: true, uniqueness: { scope: :workspace_id }, format: { with: /\A[a-z0-9_-]+\z/ }
  validates :status, presence: true, inclusion: { in: %w[active inactive draft] }
  validates :model_name, presence: true
  validates :system_prompt, presence: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { where(status: 'active') }
  scope :by_workspace, ->(workspace) { where(workspace: workspace) }

  # Configuration defaults
  DEFAULTS = {
    model_name: 'gpt-4',
    temperature: 0.7,
    max_tokens: 4096,
    streaming_enabled: false,
    webhook_enabled: false
  }.freeze

  # Available models
  SUPPORTED_MODELS = %w[
    gpt-3.5-turbo
    gpt-4
    gpt-4-turbo
    gpt-4o
    claude-3-haiku
    claude-3-sonnet
    claude-3-opus
  ].freeze

  # Initialize defaults
  after_initialize :set_defaults, if: :new_record?

  # Serialize configuration as JSON
  def config
    @config ||= (super || {}).with_indifferent_access
  end

  def config=(value)
    super(value.is_a?(Hash) ? value : {})
    @config = nil
  end

  def webhook_config
    @webhook_config ||= (super || {}).with_indifferent_access
  end

  def webhook_config=(value)
    super(value.is_a?(Hash) ? value : {})
    @webhook_config = nil
  end

  # Get effective configuration by merging defaults with overrides
  def effective_config
    DEFAULTS.merge({
      model_name: model_name,
      temperature: temperature,
      max_tokens: max_tokens,
      streaming_enabled: streaming_enabled,
      webhook_enabled: webhook_enabled,
      system_prompt: system_prompt,
      config: config,
      webhook_config: webhook_config
    })
  end

  # Get the compiled system prompt with workspace context
  def compiled_system_prompt(context = {})
    prompt_parts = []
    
    # Add agent-specific system prompt
    prompt_parts << system_prompt if system_prompt.present?
    
    # Add workspace AI configuration if available
    if workspace.respond_to?(:workspace_ai_config) && workspace.workspace_ai_config&.instructions.present?
      prompt_parts << "\nWORKSPACE INSTRUCTIONS:"
      prompt_parts << workspace.workspace_ai_config.instructions
    end
    
    # Add any additional context
    if context.present?
      context_str = context.map { |k, v| "#{k}: #{v}" }.join("\n")
      prompt_parts << "\nCONTEXT:"
      prompt_parts << context_str
    end
    
    prompt_parts.join("\n")
  end

  # Get API key for the model provider
  def api_key
    case model_name
    when /^gpt-/, /^claude-/
      workspace.respond_to?(:workspace_ai_config) ? workspace.workspace_ai_config&.api_key : ENV['OPENAI_API_KEY']
    else
      ENV['OPENAI_API_KEY'] # Default fallback
    end
  end

  # Check if agent is ready to run
  def ready?
    status == 'active' && 
    system_prompt.present? && 
    model_name.present? && 
    SUPPORTED_MODELS.include?(model_name)
  end

  # Generate a summary for display
  def summary
    {
      id: id,
      name: name,
      slug: slug,
      status: status,
      model: model_name,
      workspace: workspace&.name,
      streaming: streaming_enabled,
      webhook: webhook_enabled,
      last_run: llm_outputs.completed.recent.first&.created_at,
      created_at: created_at,
      created_by: created_by&.name
    }
  end

  private

  def generate_slug
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
  end

  def set_defaults
    DEFAULTS.each do |key, value|
      send("#{key}=", value) if send(key).nil?
    end
  end
end