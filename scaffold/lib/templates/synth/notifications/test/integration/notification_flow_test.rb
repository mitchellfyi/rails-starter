# frozen_string_literal: true

require 'test_helper'

class NotificationFlowTest < ActionDispatch::IntegrationTest
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

  test 'user can view notifications index' do
    sign_in @user
    
    get notifications_path
    
    assert_response :success
    assert_select 'h1', 'Notifications'
    assert_select '.notification-item', count: 1
    assert_select '.notification-item', text: /Test Notification/
  end

  test 'user can mark notification as read' do
    sign_in @user
    
    assert @notification.unread?
    
    patch read_notification_path(@notification)
    
    @notification.reload
    assert @notification.read?
    assert_redirected_to notifications_path
  end

  test 'user can dismiss notification' do
    sign_in @user
    
    assert @notification.active?
    
    patch dismiss_notification_path(@notification)
    
    @notification.reload
    assert @notification.dismissed?
    assert_redirected_to notifications_path
  end

  test 'user can mark all notifications as read' do
    notification2 = Notification.create!(
      user: @user,
      notification_type: 'job_completed',
      title: 'Another Notification',
      message: 'Another test notification'
    )
    
    sign_in @user
    
    assert @notification.unread?
    assert notification2.unread?
    
    patch mark_all_read_notifications_path
    
    @notification.reload
    notification2.reload
    
    assert @notification.read?
    assert notification2.read?
    assert_redirected_to notifications_path
  end

  test 'user can dismiss all notifications' do
    notification2 = Notification.create!(
      user: @user,
      notification_type: 'job_completed',
      title: 'Another Notification',
      message: 'Another test notification'
    )
    
    sign_in @user
    
    assert @notification.active?
    assert notification2.active?
    
    delete dismiss_all_notifications_path
    
    @notification.reload
    notification2.reload
    
    assert @notification.dismissed?
    assert notification2.dismissed?
    assert_redirected_to notifications_path
  end

  test 'user can view notification preferences' do
    sign_in @user
    
    get notification_preferences_path
    
    assert_response :success
    assert_select 'h1', 'Notification Preferences'
    assert_select 'input[type="checkbox"][name="notification_preference[email_notifications]"]'
    assert_select 'input[type="checkbox"][name="notification_preference[in_app_notifications]"]'
  end

  test 'user can update notification preferences' do
    sign_in @user
    
    patch notification_preferences_path, params: {
      notification_preference: {
        email_notifications: false,
        in_app_notifications: true,
        notification_types: {
          'invitation_received' => { 'email' => false, 'in_app' => true }
        }
      }
    }
    
    preference = @user.notification_preference.reload
    assert_not preference.email_notifications
    assert preference.in_app_notifications
    assert_not preference.email_enabled_for?('invitation_received')
    assert preference.in_app_enabled_for?('invitation_received')
    
    assert_redirected_to notification_preferences_path
  end

  test 'JSON API endpoints work correctly' do
    sign_in @user
    
    # Test notifications index JSON
    get notifications_path, headers: { 'Accept' => 'application/json' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['notifications'].present?
    assert_equal 1, json_response['notifications'].length
    
    notification_json = json_response['notifications'].first
    assert_equal @notification.id, notification_json['id']
    assert_equal @notification.title, notification_json['title']
    assert_equal @notification.message, notification_json['message']
    assert_equal false, notification_json['read']
    
    # Test notification preferences JSON
    get notification_preferences_path, headers: { 'Accept' => 'application/json' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['preferences'].present?
    assert json_response['preferences']['available_types'].present?
  end

  test 'user cannot access other users notifications' do
    other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      name: 'Other User'
    )
    
    other_notification = Notification.create!(
      user: other_user,
      notification_type: 'job_completed',
      title: 'Other User Notification',
      message: 'This belongs to another user'
    )
    
    sign_in @user
    
    # Should not be able to access other user's notification
    assert_raises(ActiveRecord::RecordNotFound) do
      get notification_path(other_notification)
    end
    
    assert_raises(ActiveRecord::RecordNotFound) do
      patch read_notification_path(other_notification)
    end
    
    assert_raises(ActiveRecord::RecordNotFound) do
      patch dismiss_notification_path(other_notification)
    end
  end

  private

  def sign_in(user)
    # This would depend on your authentication system
    # For Devise, it might be:
    # sign_in user
    # For a custom system, you might set session variables
    session[:user_id] = user.id
  end
end