# frozen_string_literal: true

class AiCredential < ApplicationRecord
  belongs_to :workspace
  belongs_to :ai_provider
  has_many :prompt_executions, dependent: :destroy
  has_many :llm_outputs, dependent: :destroy
  has_many :ai_usage_summaries, dependent: :destroy
  has_many :ai_credential_tests, dependent: :destroy

  validates :name, presence: true
  validates :api_key, presence: true
  validates :preferred_model, presence: true
  validates :temperature, numericality: { in: 0.0..2.0 }
  validates :max_tokens, numericality: { greater_than: 0, less_than_or_equal: 32000 }

  # Ensure only one default per provider per workspace
  validates :is_default, uniqueness: { scope: [:workspace, :ai_provider], message: "can only have one default credential per provider per workspace" }, if: :is_default?

  before_validation :set_defaults, if: :new_record?
  before_create :encrypt_api_key
  after_update :encrypt_api_key, if: :api_key_changed?
  before_destroy :ensure_not_last_credential

  scope :active, -> { where(active: true) }
  scope :for_provider, ->(provider) { where(ai_provider: provider) }
  scope :default_for_provider, ->(provider) { where(ai_provider: provider, is_default: true) }

  # Store provider-specific configuration as JSON
  serialize :provider_config, Hash

  attr_accessor :api_key_plain

  def self.best_for(workspace, provider_slug)
    provider = AiProvider.find_by(slug: provider_slug)
    return nil unless provider

    # Get default credential first, then fall back to most recently used
    workspace.ai_credentials
             .active
             .where(ai_provider: provider)
             .order(is_default: :desc, last_used_at: :desc, created_at: :desc)
             .first
  end

  def self.default_for(workspace, provider_slug)
    provider = AiProvider.find_by(slug: provider_slug)
    return nil unless provider

    workspace.ai_credentials
             .active
             .where(ai_provider: provider, is_default: true)
             .first
  end

  def api_key_decrypted
    return nil if encrypted_api_key.blank?
    
    begin
      Rails.application.message_verifier('ai_credentials').verify(encrypted_api_key)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
  end

  def api_key=(value)
    @api_key_plain = value
    self.encrypted_api_key = nil  # Will be encrypted in callback
  end

  def test_connection
    result = AiProviderTestService.new(ai_provider).test_credential(self)
    
    # Record test result
    ai_credential_tests.create!(
      successful: result[:success],
      error_message: result[:error],
      response_time: result[:response_time],
      tested_at: Time.current
    )

    # Update last tested timestamp
    update_column(:last_tested_at, Time.current)
    
    result
  end

  def test_successful?
    last_test = ai_credential_tests.order(:created_at).last
    last_test&.successful? || false
  end

  def last_test_result
    ai_credential_tests.order(:created_at).last
  end

  def supports_model?(model_name)
    ai_provider.supports_model?(model_name)
  end

  def config_with_defaults
    base_config = {
      temperature: temperature,
      max_tokens: max_tokens,
      model: preferred_model
    }
    
    ai_provider.config_with_defaults(provider_config).merge(base_config)
  end

  def create_job_runner
    AiCredentialJobRunner.new(self)
  end

  def usage_summary_for_date(date)
    ai_usage_summaries.find_by(date: date.to_date)
  end

  def total_usage(date_range = 30.days.ago..Time.current)
    ai_usage_summaries.where(date: date_range.begin.to_date..date_range.end.to_date)
                      .sum(:tokens_used)
  end

  def total_cost(date_range = 30.days.ago..Time.current)
    ai_usage_summaries.where(date: date_range.begin.to_date..date_range.end.to_date)
                      .sum(:estimated_cost)
  end

  def average_response_time(date_range = 30.days.ago..Time.current)
    summaries = ai_usage_summaries.where(date: date_range.begin.to_date..date_range.end.to_date)
    return 0.0 if summaries.empty?

    total_time = summaries.sum { |s| s.avg_response_time * s.successful_requests }
    total_requests = summaries.sum(:successful_requests)
    
    total_requests > 0 ? total_time / total_requests : 0.0
  end

  def success_rate(date_range = 30.days.ago..Time.current)
    summaries = ai_usage_summaries.where(date: date_range.begin.to_date..date_range.end.to_date)
    return 100.0 if summaries.empty?

    total_successful = summaries.sum(:successful_requests)
    total_failed = summaries.sum(:failed_requests)
    total_requests = total_successful + total_failed
    
    total_requests > 0 ? (total_successful.to_f / total_requests * 100).round(2) : 100.0
  end

  def mark_as_used!
    update_column(:last_used_at, Time.current)
  end

  def display_name
    name
  end

  def provider_name
    ai_provider.name
  end

  def can_be_deleted?
    # Can't delete if it's the only credential for this provider in the workspace
    workspace.ai_credentials.active.where(ai_provider: ai_provider).count > 1
  end

  def status
    return :inactive unless active?
    return :needs_testing if last_tested_at.blank? || last_tested_at < 24.hours.ago
    return :failed unless test_successful?
    
    :active
  end

  def status_color
    case status
    when :active then 'green'
    when :needs_testing then 'yellow'
    when :failed then 'red'
    when :inactive then 'gray'
    end
  end

  def status_text
    case status
    when :active then 'Active'
    when :needs_testing then 'Needs Testing'
    when :failed then 'Failed'
    when :inactive then 'Inactive'
    end
  end

  private

  def set_defaults
    self.temperature ||= 0.7
    self.max_tokens ||= 4096
    self.active = true if active.nil?
    
    # Set as default if it's the first credential for this provider in the workspace
    if workspace && ai_provider
      existing_default = workspace.ai_credentials
                                 .active
                                 .where(ai_provider: ai_provider, is_default: true)
                                 .exists?
      self.is_default = true unless existing_default
    end
  end

  def encrypt_api_key
    if @api_key_plain.present?
      self.encrypted_api_key = Rails.application.message_verifier('ai_credentials').generate(@api_key_plain)
      @api_key_plain = nil
    end
  end

  def ensure_not_last_credential
    if active? && workspace.ai_credentials.active.where(ai_provider: ai_provider).count == 1
      errors.add(:base, "Cannot delete the last active credential for #{ai_provider.name}")
      throw :abort
    end
  end
end