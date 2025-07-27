# frozen_string_literal: true

# Notification dropdown component for the navigation bar
class NotificationDropdownComponent < ApplicationComponent
  def initialize(user:, **html_options)
    @user = user
    @html_options = html_options
  end

  private

  attr_reader :user, :html_options

  def notifications
    @notifications ||= user.notifications.unread.recent.limit(5)
  end

  def unread_count
    @unread_count ||= user.notifications.unread.count
  end

  def has_notifications?
    notifications.any?
  end

  def dropdown_classes
    'relative inline-block text-left'
  end

  def badge_classes
    if unread_count > 0
      'absolute -top-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-xs font-medium text-white'
    else
      'hidden'
    end
  end

  def notification_item_classes(notification)
    base_classes = 'block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 border-b border-gray-100'
    base_classes += ' bg-blue-50' if notification.unread?
    base_classes
  end
end