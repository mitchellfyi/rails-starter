# frozen_string_literal: true

require 'test_helper'

class NotificationPreferenceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      name: 'Test User'
    )
    
    @preference = NotificationPreference.create!(
      user: @user,
      email_notifications: true,
      in_app_notifications: true
    )
  end

  test 'should be valid with valid attributes' do
    assert @preference.valid?
  end

  test 'should require user' do
    @preference.user = nil
    assert_not @preference.valid?
    assert_includes @preference.errors[:user], "must exist"
  end

  test 'should validate email_notifications as boolean' do
    @preference.email_notifications = 'invalid'
    assert_not @preference.valid?
  end

  test 'should validate in_app_notifications as boolean' do
    @preference.in_app_notifications = 'invalid'
    assert_not @preference.valid?
  end

  test 'should use default preferences when notification_types is nil' do
    @preference.update!(notification_types: nil)
    preferences = @preference.notification_types
    
    assert preferences.is_a?(Hash)
    assert preferences['invitation_received'].present?
    assert_equal true, preferences['invitation_received']['email']
    assert_equal true, preferences['invitation_received']['in_app']
  end

  test 'should check if email is enabled for notification type' do
    @preference.update!(
      email_notifications: true,
      notification_types: {
        'invitation_received' => { 'email' => true, 'in_app' => true },
        'job_completed' => { 'email' => false, 'in_app' => true }
      }
    )

    assert @preference.email_enabled_for?('invitation_received')
    assert_not @preference.email_enabled_for?('job_completed')
  end

  test 'should check if in_app is enabled for notification type' do
    @preference.update!(
      in_app_notifications: true,
      notification_types: {
        'invitation_received' => { 'email' => true, 'in_app' => true },
        'billing_payment_success' => { 'email' => true, 'in_app' => false }
      }
    )

    assert @preference.in_app_enabled_for?('invitation_received')
    assert_not @preference.in_app_enabled_for?('billing_payment_success')
  end

  test 'should return false for email when global email notifications disabled' do
    @preference.update!(email_notifications: false)
    
    assert_not @preference.email_enabled_for?('invitation_received')
  end

  test 'should return false for in_app when global in_app notifications disabled' do
    @preference.update!(in_app_notifications: false)
    
    assert_not @preference.in_app_enabled_for?('invitation_received')
  end

  test 'should update preference for specific type' do
    @preference.update_preference_for_type('invitation_received', email: false, in_app: true)
    
    assert_not @preference.email_enabled_for?('invitation_received')
    assert @preference.in_app_enabled_for?('invitation_received')
  end

  test 'should return channels for type' do
    @preference.update!(
      notification_types: {
        'invitation_received' => { 'email' => true, 'in_app' => true },
        'job_completed' => { 'email' => false, 'in_app' => true },
        'billing_payment_failed' => { 'email' => true, 'in_app' => false }
      }
    )

    channels = @preference.channels_for_type('invitation_received')
    assert_includes channels, :email
    assert_includes channels, :in_app

    channels = @preference.channels_for_type('job_completed')
    assert_not_includes channels, :email
    assert_includes channels, :in_app

    channels = @preference.channels_for_type('billing_payment_failed')
    assert_includes channels, :email
    assert_not_includes channels, :in_app
  end

  test 'should create preference for user' do
    new_user = User.create!(
      email: 'new@example.com',
      password: 'password123',
      name: 'New User'
    )

    # Should create new preference
    preference = NotificationPreference.for_user(new_user)
    assert preference.persisted?
    assert_equal new_user, preference.user

    # Should return existing preference
    same_preference = NotificationPreference.for_user(new_user)
    assert_equal preference, same_preference
  end

  test 'should have default preferences for all notification types' do
    default_prefs = NotificationPreference.default_preferences
    
    Notification::TYPES.each do |type|
      assert default_prefs[type].present?, "Missing default preference for #{type}"
      assert default_prefs[type]['email'].in?([true, false]), "Invalid email preference for #{type}"
      assert default_prefs[type]['in_app'].in?([true, false]), "Invalid in_app preference for #{type}"
    end
  end
end