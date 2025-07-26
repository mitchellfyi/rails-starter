# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def notification_email(notification)
    @notification = notification
    @user = notification.user
    @data = notification.data

    mail(
      to: @user.email,
      subject: notification.title
    )
  end

  private

  def default_url_options
    { host: Rails.application.routes.default_url_options[:host] || 'localhost:3000' }
  end
end