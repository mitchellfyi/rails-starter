require 'test_helper'

class UserSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should get show" do
    get settings_url
    assert_response :success
    assert_select 'h1', 'Account Settings'
  end

  test "should update profile successfully" do
    patch update_profile_settings_url, params: {
      user_settings_profile_form: {
        first_name: 'Updated',
        last_name: 'Name',
        email: 'updated@example.com',
        avatar_url: 'https://example.com/avatar.jpg'
      }
    }
    
    assert_redirected_to settings_path
    assert_equal 'Profile updated successfully', flash[:notice]
    
    @user.reload
    assert_equal 'Updated', @user.first_name
    assert_equal 'Name', @user.last_name
    assert_equal 'updated@example.com', @user.email
    assert_equal 'https://example.com/avatar.jpg', @user.avatar_url
  end

  test "should not update profile with invalid data" do
    patch update_profile_settings_url, params: {
      user_settings_profile_form: {
        first_name: '',
        last_name: '',
        email: 'invalid-email'
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.text-red-600', text: /can't be blank/
  end

  test "should not update profile with duplicate email" do
    other_user = users(:two)
    
    patch update_profile_settings_url, params: {
      user_settings_profile_form: {
        first_name: 'Test',
        last_name: 'User',
        email: other_user.email
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.text-red-600', text: /already taken/
  end

  test "should update password successfully" do
    patch update_password_settings_url, params: {
      user_settings_password_form: {
        current_password: 'password',
        password: 'newpassword123',
        password_confirmation: 'newpassword123'
      }
    }
    
    assert_redirected_to settings_path
    assert_equal 'Password updated successfully', flash[:notice]
    
    @user.reload
    assert @user.valid_password?('newpassword123')
  end

  test "should not update password with incorrect current password" do
    patch update_password_settings_url, params: {
      user_settings_password_form: {
        current_password: 'wrongpassword',
        password: 'newpassword123',
        password_confirmation: 'newpassword123'
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.text-red-600', text: /incorrect/
  end

  test "should not update password when confirmation doesn't match" do
    patch update_password_settings_url, params: {
      user_settings_password_form: {
        current_password: 'password',
        password: 'newpassword123',
        password_confirmation: 'differentpassword'
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.text-red-600', text: /doesn't match/
  end

  test "should update preferences successfully" do
    patch update_preferences_settings_url, params: {
      user_settings_preferences_form: {
        locale: 'es',
        timezone: 'America/New_York',
        email_notifications: false,
        push_notifications: true
      }
    }
    
    assert_redirected_to settings_path
    assert_equal 'Preferences updated successfully', flash[:notice]
    
    @user.reload
    assert_equal 'es', @user.locale
    assert_equal 'America/New_York', @user.timezone
    assert_equal false, @user.email_notifications
    assert_equal true, @user.push_notifications
  end

  test "should not update preferences with invalid locale" do
    patch update_preferences_settings_url, params: {
      user_settings_preferences_form: {
        locale: 'invalid_locale',
        timezone: 'UTC'
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.text-red-600'
  end

  test "should require authentication" do
    sign_out @user
    
    get settings_url
    assert_redirected_to new_user_session_path
  end
end