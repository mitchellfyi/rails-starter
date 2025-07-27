require 'test_helper'

class UserSettings::PasswordFormTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @form = UserSettings::PasswordForm.new(@user)
  end

  test "should validate presence of required fields" do
    @form.assign_attributes(
      current_password: '',
      password: '',
      password_confirmation: ''
    )
    
    assert_not @form.valid?
    assert_includes @form.errors[:current_password], "can't be blank"
    assert_includes @form.errors[:password], "can't be blank"
    assert_includes @form.errors[:password_confirmation], "can't be blank"
  end

  test "should validate minimum password length" do
    @form.assign_attributes(
      current_password: 'password',
      password: '123',
      password_confirmation: '123'
    )
    
    assert_not @form.valid?
    assert_includes @form.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "should validate password confirmation matches" do
    @form.assign_attributes(
      current_password: 'password',
      password: 'newpassword123',
      password_confirmation: 'differentpassword'
    )
    
    assert_not @form.valid?
    assert_includes @form.errors[:password_confirmation], "doesn't match password"
  end

  test "should validate current password is correct" do
    @form.assign_attributes(
      current_password: 'wrongpassword',
      password: 'newpassword123',
      password_confirmation: 'newpassword123'
    )
    
    assert_not @form.valid?
    assert_includes @form.errors[:current_password], "is incorrect"
  end

  test "should update password successfully with valid attributes" do
    # Set a known password for the user
    @user.update!(password: 'oldpassword123', password_confirmation: 'oldpassword123')
    
    valid_attributes = {
      current_password: 'oldpassword123',
      password: 'newpassword123',
      password_confirmation: 'newpassword123'
    }
    
    assert @form.update(valid_attributes)
    
    @user.reload
    assert @user.valid_password?('newpassword123')
    assert_not @user.valid_password?('oldpassword123')
  end

  test "should not update with invalid attributes" do
    original_encrypted_password = @user.encrypted_password
    
    assert_not @form.update(
      current_password: 'wrongpassword',
      password: 'newpassword123',
      password_confirmation: 'newpassword123'
    )
    
    @user.reload
    assert_equal original_encrypted_password, @user.encrypted_password
  end
end