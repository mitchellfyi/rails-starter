# frozen_string_literal: true

class SpendingLimitNotificationJob < ApplicationJob
  queue_as :default

  def perform(workspace_id:, notification_type:, limit:, current_spend:, emails:)
    workspace = Workspace.find(workspace_id)
    
    Rails.logger.info "Sending spending limit notification", {
      workspace_id: workspace_id,
      notification_type: notification_type,
      limit: limit,
      current_spend: current_spend,
      emails: emails
    }

    emails.each do |email|
      SpendingLimitMailer.limit_exceeded(
        email: email,
        workspace: workspace,
        limit_type: notification_type,
        limit_amount: limit,
        current_spend: current_spend
      ).deliver_now
    end
  rescue => e
    Rails.logger.error "Failed to send spending limit notification", {
      workspace_id: workspace_id,
      error: e.message,
      backtrace: e.backtrace.first(5)
    }
    raise
  end
end