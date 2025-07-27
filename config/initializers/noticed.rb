# frozen_string_literal: true

# Noticed gem configuration for unified notification system
# Provides both in-app and email notifications

if defined?(Noticed)
  # Configure default delivery methods
  Noticed.configure do |config|
    # Set default delivery methods for notifications
    config.parent_class = 'ApplicationNotification'
    
    # Configure serialization for complex data
    config.serialize_with = :json
  end
  
  Rails.logger.info '📢 Noticed notification system configured'
end

# Base notification class that other notifications inherit from
class ApplicationNotification < Noticed::Event
  # Default delivery methods - can be overridden in specific notifications
  deliver_by :database
  deliver_by :email, mailer: 'NotificationMailer', delay: 5.minutes, if: :email_notifications_enabled?
  
  # Optional browser notification for real-time updates
  # deliver_by :action_cable, channel: 'NotificationChannel', if: :realtime_enabled?
  
  private
  
  def email_notifications_enabled?
    recipient.respond_to?(:email_notifications?) ? recipient.email_notifications? : true
  end
  
  def realtime_enabled?
    recipient.respond_to?(:realtime_notifications?) ? recipient.realtime_notifications? : false
  end
end

# Example notification classes
class WorkspaceInvitationNotification < ApplicationNotification
  deliver_by :email, mailer: 'WorkspaceMailer', method: :invitation_notification
  
  param :workspace
  param :inviter
  param :invitation_token
end

class WorkspaceMemberJoinedNotification < ApplicationNotification
  deliver_by :database
  deliver_by :email, mailer: 'WorkspaceMailer', method: :member_joined_notification, if: :notify_owner?
  
  param :workspace
  param :new_member
  
  private
  
  def notify_owner?
    recipient.workspace_memberships.find_by(workspace: params[:workspace])&.owner?
  end
end

class SystemMaintenanceNotification < ApplicationNotification
  deliver_by :database
  deliver_by :email, mailer: 'SystemMailer', method: :maintenance_notification
  
  param :maintenance_window
  param :affected_services
end