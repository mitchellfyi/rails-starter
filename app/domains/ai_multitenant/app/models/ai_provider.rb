# frozen_string_literal: true

class AiProvider < ApplicationRecord
  has_many :ai_credentials, dependent: :destroy
  has_many :workspaces, through: :ai_credentials

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :api_base_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(:priority, :name) }

  # Supported models should be an array of strings
  serialize :supported_models, Array
  serialize :default_config, Hash

  def self.openai
    find_by(slug: 'openai')
  end

  def self.anthropic
    find_by(slug: 'anthropic')
  end

  def self.available_for_workspace(workspace)
    joins(:ai_credentials).where(ai_credentials: { workspace: workspace, active: true }).distinct
  end

  def supports_model?(model_name)
    supported_models.include?(model_name.to_s)
  end

  def test_connection(api_key = nil)
    AiProviderTestService.new(self).test_connection(api_key)
  end

  def credentials_for_workspace(workspace)
    ai_credentials.where(workspace: workspace, active: true)
  end

  def default_credential_for_workspace(workspace)
    credentials_for_workspace(workspace).where(is_default: true).first ||
      credentials_for_workspace(workspace).first
  end

  def model_options
    supported_models.map { |model| [model.humanize, model] }
  end

  def config_with_defaults(custom_config = {})
    (default_config || {}).merge(custom_config || {})
  end

  def display_name
    name
  end

  def status_for_workspace(workspace)
    credentials = credentials_for_workspace(workspace)
    return :not_configured if credentials.empty?
    
    # Check if any credentials have been tested recently and successfully
    recent_successful = credentials.joins(:ai_credential_tests)
                                   .where(ai_credential_tests: { 
                                     successful: true, 
                                     created_at: 1.hour.ago.. 
                                   })
                                   .exists?
    
    recent_successful ? :active : :needs_testing
  end

  def usage_stats_for_workspace(workspace, date_range = 30.days.ago..Time.current)
    AiUsageSummary.joins(:ai_credential)
                  .where(ai_credentials: { ai_provider: self, workspace: workspace })
                  .where(date: date_range.begin.to_date..date_range.end.to_date)
                  .group(:date)
                  .sum(:tokens_used)
  end

  private

  def generate_slug
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')
  end
end