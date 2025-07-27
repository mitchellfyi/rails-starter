# frozen_string_literal: true

# Enhanced notification model that works with Noticed gem
class Notification < ApplicationRecord
  include Noticed::Model
  belongs_to :recipient, polymorphic: true
  
  # Scopes for filtering notifications
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_type, ->(type) { where(type: type) }
  
  # Mark notification as read
  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end
  
  # Check if notification is read
  def read?
    read_at.present?
  end
  
  # Check if notification is unread
  def unread?
    !read?
  end
  
  # Get the notification icon based on type
  def icon
    case type
    when 'WorkspaceInvitationNotification'
      'user-plus'
    when 'WorkspaceMemberJoinedNotification'
      'users'
    when 'SystemMaintenanceNotification'
      'exclamation-triangle'
    else
      'bell'
    end
  end
  
  # Get the notification color based on type
  def color
    case type
    when 'WorkspaceInvitationNotification'
      'blue'
    when 'WorkspaceMemberJoinedNotification'
      'green'
    when 'SystemMaintenanceNotification'
      'yellow'
    else
      'gray'
    end
  end
  
  # Human-readable notification message
  def message
    case type
    when 'WorkspaceInvitationNotification'
      "#{params['inviter']['name']} invited you to join #{params['workspace']['name']}"
    when 'WorkspaceMemberJoinedNotification'
      "#{params['new_member']['name']} joined #{params['workspace']['name']}"
    when 'SystemMaintenanceNotification'
      "Scheduled maintenance: #{params['maintenance_window']}"
    else
      'You have a new notification'
    end
  end
  
  # Get the action URL for the notification
  def action_url
    case type
    when 'WorkspaceInvitationNotification'
      Rails.application.routes.url_helpers.workspace_invitation_path(params['invitation_token'])
    when 'WorkspaceMemberJoinedNotification'
      Rails.application.routes.url_helpers.workspace_path(params['workspace']['slug'])
    else
      Rails.application.routes.url_helpers.notifications_path
    end
  end
end