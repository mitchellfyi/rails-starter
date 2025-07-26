# frozen_string_literal: true

class NotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, notification_type, title, message, data = {}, channels = [:email, :in_app])
    user = User.find(user_id)
    preferences = NotificationPreference.for_user(user)
    
    # Determine which channels to use based on user preferences
    enabled_channels = preferences.channels_for_type(notification_type) & channels.map(&:to_sym)
    
    return if enabled_channels.empty?
    
    # Create in-app notification if enabled
    if enabled_channels.include?(:in_app)
      notification = user.notifications.create!(
        notification_type: notification_type,
        title: title,
        message: message,
        data: data
      )
      
      # Broadcast to user's notification channel for real-time updates
      broadcast_notification(notification)
    end
    
    # Send email notification if enabled
    if enabled_channels.include?(:email)
      # Create a temporary notification object for email if in-app is disabled
      notification ||= Notification.new(
        user: user,
        notification_type: notification_type,
        title: title,
        message: message,
        data: data
      )
      
      NotificationMailer.notification_email(notification).deliver_now
    end
  end

  private

  def broadcast_notification(notification)
    # Broadcast to user's notification channel using Turbo Streams
    Turbo::StreamsChannel.broadcast_replace_to(
      "notifications_#{notification.user_id}",
      target: "notification_count",
      partial: "shared/notification_count",
      locals: { count: notification.user.unread_notifications_count }
    )
    
    # Broadcast new notification to feed
    Turbo::StreamsChannel.broadcast_prepend_to(
      "notifications_#{notification.user_id}",
      target: "notification_feed",
      partial: "notifications/notification",
      locals: { notification: notification }
    )
    
    # Broadcast toast notification
    Turbo::StreamsChannel.broadcast_append_to(
      "notification_toasts_#{notification.user_id}",
      target: "notification_toasts",
      partial: "notifications/toast",
      locals: { notification: notification }
    )
  end
end