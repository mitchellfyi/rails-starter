# frozen_string_literal: true

class BulkNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_ids, notification_type, title, message, data = {}, channels = [:email, :in_app])
    user_ids.each do |user_id|
      NotificationJob.perform_later(user_id, notification_type, title, message, data, channels)
    end
  end
end