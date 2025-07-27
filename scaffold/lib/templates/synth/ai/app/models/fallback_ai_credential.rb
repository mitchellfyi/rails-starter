# frozen_string_literal: true

class FallbackAiCredential < ApplicationRecord
  belongs_to :ai_provider
  belongs_to :created_by, class_name: 'User'
  has_many :llm_outputs, foreign_key: :fallback_credential_id, dependent: :nullify
  has_many :fallback_credential_usages, dependent: :destroy
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: :ai_provider_id }
  validates :encrypted_api_key, presence: true
  validates :preferred_model, presence: true
  validates :temperature, presence: true, inclusion: { in: 0.0..2.0 }
  validates :max_tokens, presence: true, inclusion: { in: 1..100000 }
  validates :response_format, presence: true, inclusion: { in: %w[text json markdown html] }
  validates :usage_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :daily_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :expires_at, comparison: { greater_than: :created_at }, allow_nil: true
  
  validate :model_supported_by_provider
  
  # Encrypt API key using Rails credentials
  encrypts :api_key
  
  scope :active, -> { where(active: true) }
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :within_limits, -> { where('usage_limit IS NULL OR total_usage_count < usage_limit') }
  scope :for_provider, ->(provider_slug) { joins(:ai_provider).where(ai_providers: { slug: provider_slug }) }
  scope :available, -> { active.not_expired.within_limits }
  
  # Get the best available fallback credential for a provider
  def self.best_for_provider(provider_slug)
    available
      .for_provider(provider_slug)
      .order(:priority, :total_usage_count)
      .first
  end
  
  # Check if credential is available for use
  def available?
    active? && !expired? && within_usage_limit? && within_daily_limit?
  end
  
  # Check if credential has expired
  def expired?
    expires_at.present? && expires_at < Time.current
  end
  
  # Check if within total usage limit
  def within_usage_limit?
    usage_limit.nil? || total_usage_count < usage_limit
  end
  
  # Check if within daily usage limit
  def within_daily_limit?
    return true if daily_limit.nil?
    
    daily_usage_count < daily_limit
  end
  
  # Get today's usage count
  def daily_usage_count
    fallback_credential_usages
      .where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
      .sum(:usage_count)
  end
  
  # Record usage for a user/workspace
  def record_usage(user:, workspace: nil, usage_count: 1)
    return false unless available?
    
    usage_record = fallback_credential_usages.find_or_initialize_by(
      user: user,
      workspace: workspace,
      date: Date.current
    )
    
    usage_record.usage_count = (usage_record.usage_count || 0) + usage_count
    usage_record.last_used_at = Time.current
    
    if usage_record.save
      increment!(:total_usage_count, usage_count)
      update!(last_used_at: Time.current)
      true
    else
      false
    end
  end
  
  # Get usage for a specific user
  def usage_for_user(user, workspace: nil)
    fallback_credential_usages
      .where(user: user, workspace: workspace)
      .sum(:usage_count)
  end
  
  # Get daily usage for a specific user
  def daily_usage_for_user(user, workspace: nil)
    fallback_credential_usages
      .where(
        user: user,
        workspace: workspace,
        date: Date.current
      )
      .sum(:usage_count)
  end
  
  # Test the credential by pinging the provider
  def test_connection
    service = AiProviderTestService.new(self)
    service.test_connection
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
  
  # Get remaining usage count
  def remaining_usage
    return Float::INFINITY if usage_limit.nil?
    
    usage_limit - total_usage_count
  end
  
  # Get remaining daily usage
  def remaining_daily_usage
    return Float::INFINITY if daily_limit.nil?
    
    daily_limit - daily_usage_count
  end
  
  # Get usage statistics
  def usage_stats
    {
      total_usage: total_usage_count,
      usage_limit: usage_limit,
      remaining_usage: remaining_usage,
      daily_usage: daily_usage_count,
      daily_limit: daily_limit,
      remaining_daily_usage: remaining_daily_usage,
      unique_users: fallback_credential_usages.distinct.count(:user_id),
      active_today: fallback_credential_usages
        .where(date: Date.current)
        .distinct
        .count(:user_id)
    }
  end
  
  private
  
  def model_supported_by_provider
    return unless ai_provider && preferred_model.present?
    
    unless ai_provider.supports_model?(preferred_model)
      errors.add(:preferred_model, "is not supported by #{ai_provider.name}")
    end
  end
end