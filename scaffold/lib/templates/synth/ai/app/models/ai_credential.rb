# frozen_string_literal: true

class AiCredential < ApplicationRecord
  belongs_to :workspace
  belongs_to :ai_provider
  belongs_to :imported_by, class_name: 'User', optional: true
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
  scope :imported_from_environment, -> { where.not(environment_source: nil) }
  scope :synced_from_vault, -> { where.not(vault_secret_key: nil) }
  scope :synced_from_doppler, -> { where.not(doppler_secret_name: nil) }
  scope :synced_from_onepassword, -> { where.not(onepassword_item_id: nil) }
  
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
  
  # Check if credential was imported from environment
  def imported_from_environment?
    environment_source.present?
  end
  
  # Check if credential is synced from external secret manager
  def synced_from_external?
    vault_secret_key.present? || doppler_secret_name.present? || onepassword_item_id.present?
  end
  
  # Get the external secret manager source
  def external_source
    return 'Vault' if vault_secret_key.present?
    return 'Doppler' if doppler_secret_name.present?
    return '1Password' if onepassword_item_id.present?
    return 'Environment' if environment_source.present?
    'Manual'
  end
  
  # Sync with external secret manager
  def sync_with_external_source
    return { success: false, error: 'No external source configured' } unless synced_from_external?
    
    if vault_secret_key.present?
      sync_with_vault
    elsif doppler_secret_name.present?
      sync_with_doppler
    elsif onepassword_item_id.present?
      sync_with_onepassword
    else
      { success: false, error: 'Unknown external source' }
    end
  end
  
  # Check if credential needs to be refreshed from external source
  def needs_external_sync?
    return false unless synced_from_external?
    
    last_sync_time = vault_synced_at || doppler_synced_at || onepassword_synced_at
    return true unless last_sync_time
    
    last_sync_time < 1.hour.ago
  end
  
  # Decrypt and return API key (handled by encrypts automatically)
  def api_key
    super
  end
  
  private
  
  def sync_with_vault
    service = VaultIntegrationService.new
    result = service.fetch_credential_from_vault("#{service.config[:secrets_path]}/#{workspace.slug}/#{ai_provider.slug}/#{id}")
    
    if result[:success]
      update!(
        api_key: result[:data]['api_key'],
        vault_synced_at: Time.current
      )
      { success: true, message: 'Synced from Vault' }
    else
      result
    end
  end
  
  def sync_with_doppler
    service = DopplerIntegrationService.new
    result = service.fetch_secret_from_doppler(doppler_secret_name)
    
    if result[:success]
      update!(
        api_key: result[:value],
        doppler_synced_at: Time.current
      )
      { success: true, message: 'Synced from Doppler' }
    else
      result
    end
  end
  
  def sync_with_onepassword
    service = OnePasswordIntegrationService.new
    result = service.fetch_credential_from_onepassword(onepassword_item_id)
    
    if result[:success]
      api_key_value = service.send(:extract_api_key_from_item, result[:data])
      if api_key_value.present?
        update!(
          api_key: api_key_value,
          onepassword_synced_at: Time.current
        )
        { success: true, message: 'Synced from 1Password' }
      else
        { success: false, error: 'API key not found in 1Password item' }
      end
    else
      result
    end
  end
  
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