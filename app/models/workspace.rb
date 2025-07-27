# frozen_string_literal: true

class Workspace < ApplicationRecord
  has_many :workspace_feature_flags, dependent: :destroy
  has_many :feature_flags, through: :workspace_feature_flags
  has_many :workspace_mcp_fetchers, dependent: :destroy
  has_many :mcp_fetchers, through: :workspace_mcp_fetchers
  
  validates :name, presence: true
  
  def enabled_mcp_fetchers
    mcp_fetchers.joins(:workspace_mcp_fetchers)
                .where(workspace_mcp_fetchers: { enabled: true })
                .union(
                  McpFetcher.enabled.where.not(
                    id: workspace_mcp_fetchers.select(:mcp_fetcher_id)
                  )
                )
  end
  
  def mcp_fetcher_enabled?(fetcher)
    fetcher.enabled_for_workspace?(self)
  end
end