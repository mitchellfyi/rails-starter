# frozen_string_literal: true

class McpFetcher < ApplicationRecord
  has_many :workspace_mcp_fetchers, dependent: :destroy
  has_many :workspaces, through: :workspace_mcp_fetchers
  
  validates :name, presence: true, uniqueness: true
  validates :provider_type, presence: true
  validates :description, presence: true
  validate :configuration_is_valid_json
  validate :parameters_is_valid_json
  
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :by_provider_type, ->(type) { where(provider_type: type) }
  
  def enabled_for_workspace?(workspace)
    return enabled unless workspace
    
    workspace_fetcher = workspace_mcp_fetchers.find_by(workspace: workspace)
    workspace_fetcher ? workspace_fetcher.enabled : enabled
  end
  
  def workspace_override?(workspace)
    workspace_mcp_fetchers.exists?(workspace: workspace)
  end
  
  def workspace_status(workspace)
    return 'Global' unless workspace
    
    workspace_fetcher = workspace_mcp_fetchers.find_by(workspace: workspace)
    if workspace_fetcher
      workspace_fetcher.enabled? ? 'Enabled for Workspace' : 'Disabled for Workspace'
    else
      enabled? ? 'Inherited (Enabled)' : 'Inherited (Disabled)'
    end
  end
  
  def toggle_for_workspace!(workspace)
    workspace_fetcher = workspace_mcp_fetchers.find_or_initialize_by(workspace: workspace)
    workspace_fetcher.enabled = !workspace_fetcher.enabled
    workspace_fetcher.save!
  end
  
  def workspace_configuration_for(workspace)
    return configuration unless workspace
    
    workspace_fetcher = workspace_mcp_fetchers.find_by(workspace: workspace)
    if workspace_fetcher && workspace_fetcher.workspace_configuration.present?
      configuration.merge(workspace_fetcher.workspace_configuration)
    else
      configuration
    end
  end
  
  def sample_output_preview
    return 'No sample output' if sample_output.blank?
    sample_output.truncate(100)
  end

  private

  def configuration_is_valid_json
    return if configuration.blank?
    
    if configuration.is_a?(String)
      begin
        JSON.parse(configuration)
      rescue JSON::ParserError
        errors.add(:configuration, 'must be valid JSON')
      end
    end
  end

  def parameters_is_valid_json
    return if parameters.blank?
    
    if parameters.is_a?(String)
      begin
        JSON.parse(parameters)
      rescue JSON::ParserError
        errors.add(:parameters, 'must be valid JSON')
      end
    end
  end
end