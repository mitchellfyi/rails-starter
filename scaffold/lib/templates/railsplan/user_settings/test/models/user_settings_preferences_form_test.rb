require 'test_helper'

class UserSettings::PreferencesFormTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @form = UserSettings::PreferencesForm.new(@user)
  end

  test "should initialize with user attributes or defaults" do
    # Test with user that has preferences set
    @user.update!(
      locale: 'es',
      timezone: 'America/New_York',
      email_notifications: false,
      push_notifications: true
    )
    
    form = UserSettings::PreferencesForm.new(@user)
    assert_equal 'es', form.locale
    assert_equal 'America/New_York', form.timezone
    assert_equal false, form.email_notifications
    assert_equal true, form.push_notifications
  end

  test "should use defaults for new user without preferences" do
    @user.update!(
      locale: nil,
      timezone: nil,
      email_notifications: nil,
      push_notifications: nil
    )
    
    form = UserSettings::PreferencesForm.new(@user)
    assert_equal I18n.default_locale.to_s, form.locale
    assert_equal 'UTC', form.timezone
    assert_equal true, form.email_notifications
    assert_equal true, form.push_notifications
  end

  test "should validate locale is available" do
    @form.assign_attributes(locale: 'invalid_locale')
    
    assert_not @form.valid?
    assert_includes @form.errors[:locale], "is not included in the list"
  end

  test "should validate timezone is valid" do
    @form.assign_attributes(timezone: 'Invalid/Timezone')
    
    assert_not @form.valid?
    assert_includes @form.errors[:timezone], "is not included in the list"
  end

  test "should accept valid locales" do
    I18n.available_locales.each do |locale|
      @form.assign_attributes(locale: locale.to_s)
      assert @form.valid?, "Locale #{locale} should be valid"
    end
  end

  test "should accept valid timezones" do
    valid_timezones = ['UTC', 'America/New_York', 'Europe/London', 'Asia/Tokyo']
    
    valid_timezones.each do |timezone|
      @form.assign_attributes(timezone: timezone)
      assert @form.valid?, "Timezone #{timezone} should be valid"
    end
  end

  test "should update user preferences successfully" do
    preferences = {
      locale: 'es',
      timezone: 'America/New_York',
      email_notifications: false,
      push_notifications: true
    }
    
    assert @form.update(preferences)
    
    @user.reload
    assert_equal 'es', @user.locale
    assert_equal 'America/New_York', @user.timezone
    assert_equal false, @user.email_notifications
    assert_equal true, @user.push_notifications
  end

  test "should not update with invalid preferences" do
    original_locale = @user.locale
    original_timezone = @user.timezone
    
    assert_not @form.update(
      locale: 'invalid_locale',
      timezone: 'Invalid/Timezone'
    )
    
    @user.reload
    assert_equal original_locale, @user.locale
    assert_equal original_timezone, @user.timezone
  end

  test "should handle boolean notifications correctly" do
    # Test with string values (as they come from forms)
    assert @form.update(
      locale: 'en',
      timezone: 'UTC',
      email_notifications: '1',
      push_notifications: '0'
    )
    
    @user.reload
    assert_equal true, @user.email_notifications
    assert_equal false, @user.push_notifications
  end
end