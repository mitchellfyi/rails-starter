require 'test_helper'

class UserSettingsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(
      first_name: 'John',
      last_name: 'Doe',
      email: 'john@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
    sign_in @user
  end

  test "complete user settings flow" do
    # Visit settings page
    get settings_path
    assert_response :success
    assert_select 'h1', 'Account Settings'
    
    # Test profile update
    assert_select 'form[action=?]', update_profile_settings_path do
      assert_select 'input[name=?]', 'user_settings_profile_form[first_name]'
      assert_select 'input[name=?]', 'user_settings_profile_form[last_name]'
      assert_select 'input[name=?]', 'user_settings_profile_form[email]'
      assert_select 'input[name=?]', 'user_settings_profile_form[avatar_url]'
    end
    
    # Update profile
    patch update_profile_settings_path, params: {
      user_settings_profile_form: {
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'jane@example.com',
        avatar_url: 'https://example.com/avatar.jpg'
      }
    }
    
    assert_redirected_to settings_path
    follow_redirect!
    assert_select '.text-green-600, .bg-green-100, [class*="success"]'
    
    # Verify profile was updated
    @user.reload
    assert_equal 'Jane', @user.first_name
    assert_equal 'Smith', @user.last_name
    assert_equal 'jane@example.com', @user.email
    
    # Test password update
    patch update_password_settings_path, params: {
      user_settings_password_form: {
        current_password: 'password123',
        password: 'newpassword456',
        password_confirmation: 'newpassword456'
      }
    }
    
    assert_redirected_to settings_path
    follow_redirect!
    
    # Verify password was updated
    @user.reload
    assert @user.valid_password?('newpassword456')
    
    # Test preferences update
    patch update_preferences_settings_path, params: {
      user_settings_preferences_form: {
        locale: 'es',
        timezone: 'America/New_York',
        email_notifications: '0',
        push_notifications: '1'
      }
    }
    
    assert_redirected_to settings_path
    follow_redirect!
    
    # Verify preferences were updated
    @user.reload
    assert_equal 'es', @user.locale
    assert_equal 'America/New_York', @user.timezone
    assert_equal false, @user.email_notifications
    assert_equal true, @user.push_notifications
  end

  test "should display validation errors inline" do
    # Try to update profile with invalid data
    patch update_profile_settings_path, params: {
      user_settings_profile_form: {
        first_name: '',
        last_name: '',
        email: 'invalid-email'
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.text-red-600', minimum: 1
    assert_select 'input[name=?][value=""]', 'user_settings_profile_form[first_name]'
  end

  test "should handle OAuth account management" do
    # Create an identity for the user
    identity = Identity.create!(
      user: @user,
      provider: 'google',
      uid: '123456',
      email: @user.email,
      name: @user.full_name
    )
    
    get settings_path
    assert_response :success
    
    # Should show connected account
    assert_select 'div', text: /Google/
    assert_select 'a[href=?]', oauth_account_path(identity), text: /Disconnect/
    
    # Disconnect the account
    delete oauth_account_path(identity)
    assert_redirected_to settings_path
    follow_redirect!
    
    # Verify account was disconnected
    assert_not Identity.exists?(identity.id)
    assert_select 'a', text: /Connect/, count: 3 # Should show connect links for all providers
  end

  test "should display two-factor authentication status" do
    get settings_path
    assert_response :success
    
    # Should show 2FA section
    assert_select 'h2', text: /Two-Factor Authentication/
    
    # When 2FA is disabled
    assert_select 'a[href=?]', two_factor_path, text: /Enable 2FA/
    
    # Enable 2FA for user
    @user.update!(two_factor_enabled: true, two_factor_secret: 'test_secret')
    
    get settings_path
    assert_response :success
    
    # When 2FA is enabled
    assert_select 'span', text: /enabled/
    assert_select 'a[href=?]', two_factor_path, text: /Manage 2FA/
  end

  test "should require authentication for all actions" do
    sign_out @user
    
    # Test all settings routes require authentication
    get settings_path
    assert_redirected_to new_user_session_path
    
    patch update_profile_settings_path, params: { user_settings_profile_form: {} }
    assert_redirected_to new_user_session_path
    
    patch update_password_settings_path, params: { user_settings_password_form: {} }
    assert_redirected_to new_user_session_path
    
    patch update_preferences_settings_path, params: { user_settings_preferences_form: {} }
    assert_redirected_to new_user_session_path
  end
end