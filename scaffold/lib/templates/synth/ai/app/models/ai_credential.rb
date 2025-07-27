# frozen_string_literal: true

class AiCredential < ApplicationRecord
  belongs_to :workspace
  belongs_to :ai_provider
  has_many :llm_outputs, foreign_key: :ai_credential_id, dependent: :nullify
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:workspace_id, :ai_provider_id] }
  validates :encrypted_api_key, presence: true
  validates :preferred_model, presence: true
  validates :temperature, presence: true, inclusion: { in: 0.0..2.0 }
  validates :max_tokens, presence: true, inclusion: { in: 1..100000 }
  validates :response_format, presence: true, inclusion: { in: %w[text json markdown html] }
  
  validate :model_supported_by_provider
  validate :only_one_default_per_provider_workspace
  
  # Encrypt API key using Rails credentials
  encrypts :api_key
  
  scope :active, -> { where(active: true) }
  scope :for_provider, ->(provider_slug) { joins(:ai_provider).where(ai_providers: { slug: provider_slug }) }
  scope :default_for_workspace, -> { where(is_default: true) }
  
  # Get the default credential for a workspace and provider
  def self.default_for(workspace, provider_slug)
    joins(:ai_provider)
      .where(workspace: workspace, ai_providers: { slug: provider_slug }, is_default: true)
      .first
  end
  
  # Get the best available credential for a workspace and provider
  def self.best_for(workspace, provider_slug)
    default_for(workspace, provider_slug) || 
    joins(:ai_provider)
      .where(workspace: workspace, ai_providers: { slug: provider_slug }, active: true)
      .order(:last_used_at)
      .first
  end
  
  # Test the credential by pinging the provider
  def test_connection
    service = AiProviderTestService.new(self)
    service.test_connection
  end
  
  # Check if the credential test was successful
  def test_successful?
    service = AiProviderTestService.new(self)
    service.last_test_successful?
  end
  
  # Get detailed test history
  def test_history
    service = AiProviderTestService.new(self)
    service.test_history
  end
  
  # Mark credential as used
  def mark_used!
    update!(
      last_used_at: Time.current,
      usage_count: usage_count + 1
    )
  end
  
  # Get configuration hash for LLM API calls
  def api_config
    base_config = {
      model: preferred_model,
      temperature: temperature,
      max_tokens: max_tokens
    }
    
    # Merge provider-specific configuration
    base_config.merge(provider_config)
  end
  
  # Get full configuration including API key for service calls
  def full_config
    api_config.merge(
      api_key: api_key,
      provider: ai_provider.slug,
      base_url: ai_provider.api_base_url
    )
  end
  
  # Create a scoped LLM job runner
  def create_job_runner
    AiCredentialJobRunner.new(self)
  end
  
  # Decrypt and return API key (handled by encrypts automatically)
  def api_key
    super
  end
  
  private
  
  def model_supported_by_provider
    return unless ai_provider && preferred_model.present?
    
    unless ai_provider.supports_model?(preferred_model)
      errors.add(:preferred_model, "is not supported by #{ai_provider.name}")
    end
  end
  
  def only_one_default_per_provider_workspace
    return unless is_default?
    
    existing_default = self.class
      .where(workspace: workspace, ai_provider: ai_provider, is_default: true)
      .where.not(id: id)
      .exists?
    
    if existing_default
      errors.add(:is_default, "only one default credential allowed per provider in a workspace")
    end
  end
end