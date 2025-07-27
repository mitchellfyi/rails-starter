# frozen_string_literal: true

class Admin::DashboardController < Admin::BaseController
  def index
    @user_count = User.count if defined?(User)
    @recent_audit_logs = AuditLog.recent.limit(10) if defined?(AuditLog)
    @active_feature_flags = FeatureFlag.active.count if defined?(FeatureFlag)
    @active_mcp_fetchers = McpFetcher.enabled.count if defined?(McpFetcher)
  end
end