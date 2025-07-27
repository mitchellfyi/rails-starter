# frozen_string_literal: true

class WorkspaceMcpFetcher < ApplicationRecord
  belongs_to :workspace
  belongs_to :mcp_fetcher
  
  validates :workspace_id, uniqueness: { scope: :mcp_fetcher_id }
  
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  
  def configuration
    mcp_fetcher.configuration.merge(workspace_configuration || {})
  end
end