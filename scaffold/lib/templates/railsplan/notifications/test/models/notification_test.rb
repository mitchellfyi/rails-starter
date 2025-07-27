# frozen_string_literal: true

require 'test_helper'

class NotificationTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      name: 'Test User'
    )
    
    @notification = Notification.create!(
      user: @user,
      notification_type: 'invitation_received',
      title: 'Test Notification',
      message: 'This is a test notification'
    )
  end

  test 'should be valid with valid attributes' do
    assert @notification.valid?
  end

  test 'should require user' do
    @notification.user = nil
    assert_not @notification.valid?
    assert_includes @notification.errors[:user], "must exist"
  end

  test 'should require notification_type' do
    @notification.notification_type = nil
    assert_not @notification.valid?
    assert_includes @notification.errors[:notification_type], "can't be blank"
  end

  test 'should require title' do
    @notification.title = nil
    assert_not @notification.valid?
    assert_includes @notification.errors[:title], "can't be blank"
  end

  test 'should require message' do
    @notification.message = nil
    assert_not @notification.valid?
    assert_includes @notification.errors[:message], "can't be blank"
  end

  test 'should validate notification_type inclusion' do
    @notification.notification_type = 'invalid_type'
    assert_not @notification.valid?
    assert_includes @notification.errors[:notification_type], "is not included in the list"
  end

  test 'should be unread by default' do
    assert @notification.unread?
    assert_not @notification.read?
  end

  test 'should be active by default' do
    assert @notification.active?
    assert_not @notification.dismissed?
  end

  test 'should mark as read' do
    @notification.mark_as_read!
    assert @notification.read?
    assert_not @notification.unread?
    assert @notification.read_at.present?
  end

  test 'should mark as unread' do
    @notification.mark_as_read!
    @notification.mark_as_unread!
    assert @notification.unread?
    assert_not @notification.read?
    assert_nil @notification.read_at
  end

  test 'should dismiss notification' do
    @notification.dismiss!
    assert @notification.dismissed?
    assert_not @notification.active?
    assert @notification.dismissed_at.present?
  end

  test 'should return correct icon for notification type' do
    @notification.notification_type = 'billing_payment_failed'
    assert_equal 'credit-card', @notification.icon

    @notification.notification_type = 'admin_alert'
    assert_equal 'exclamation-triangle', @notification.icon
  end

  test 'should return correct priority for notification type' do
    @notification.notification_type = 'admin_alert'
    assert_equal 'high', @notification.priority

    @notification.notification_type = 'job_completed'
    assert_equal 'low', @notification.priority
  end

  test 'should generate correct CSS classes' do
    classes = @notification.css_classes
    assert_includes classes, 'notification-item'
    assert_includes classes, 'unread'
    assert_includes classes, 'priority-medium'
    assert_includes classes, 'type-invitation-received'
  end

  test 'should scope unread notifications' do
    read_notification = Notification.create!(
      user: @user,
      notification_type: 'job_completed',
      title: 'Read Notification',
      message: 'This notification is read',
      read_at: Time.current
    )

    unread_notifications = Notification.unread
    assert_includes unread_notifications, @notification
    assert_not_includes unread_notifications, read_notification
  end

  test 'should scope notifications by type' do
    billing_notification = Notification.create!(
      user: @user,
      notification_type: 'billing_payment_failed',
      title: 'Billing Notification',
      message: 'Payment failed'
    )

    invitation_notifications = Notification.by_type('invitation_received')
    billing_notifications = Notification.by_type('billing_payment_failed')

    assert_includes invitation_notifications, @notification
    assert_not_includes invitation_notifications, billing_notification
    assert_includes billing_notifications, billing_notification
    assert_not_includes billing_notifications, @notification
  end

  test 'should mark all notifications as read for user' do
    notification2 = Notification.create!(
      user: @user,
      notification_type: 'job_completed',
      title: 'Another Notification',
      message: 'Another test notification'
    )

    assert @notification.unread?
    assert notification2.unread?

    Notification.mark_all_read_for_user(@user)

    @notification.reload
    notification2.reload

    assert @notification.read?
    assert notification2.read?
  end

  test 'should dismiss all notifications for user' do
    notification2 = Notification.create!(
      user: @user,
      notification_type: 'job_completed',
      title: 'Another Notification',
      message: 'Another test notification'
    )

    assert @notification.active?
    assert notification2.active?

    Notification.dismiss_all_for_user(@user)

    @notification.reload
    notification2.reload

    assert @notification.dismissed?
    assert notification2.dismissed?
  end
end