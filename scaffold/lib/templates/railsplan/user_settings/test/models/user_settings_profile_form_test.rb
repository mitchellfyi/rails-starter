require 'test_helper'

class UserSettings::ProfileFormTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @form = UserSettings::ProfileForm.new(@user)
  end

  test "should initialize with user attributes" do
    assert_equal @user.first_name, @form.first_name
    assert_equal @user.last_name, @form.last_name
    assert_equal @user.email, @form.email
    assert_equal @user.avatar_url, @form.avatar_url
  end

  test "should validate presence of required fields" do
    @form.assign_attributes(first_name: '', last_name: '', email: '')
    
    assert_not @form.valid?
    assert_includes @form.errors[:first_name], "can't be blank"
    assert_includes @form.errors[:last_name], "can't be blank"
    assert_includes @form.errors[:email], "can't be blank"
  end

  test "should validate email format" do
    @form.assign_attributes(email: 'invalid-email')
    
    assert_not @form.valid?
    assert_includes @form.errors[:email], "is invalid"
  end

  test "should validate avatar URL format" do
    @form.assign_attributes(avatar_url: 'invalid-url')
    
    assert_not @form.valid?
    assert_includes @form.errors[:avatar_url], "is invalid"
  end

  test "should allow blank avatar URL" do
    @form.assign_attributes(avatar_url: '')
    
    assert @form.valid?
  end

  test "should validate maximum length for names" do
    long_name = 'a' * 51
    @form.assign_attributes(first_name: long_name, last_name: long_name)
    
    assert_not @form.valid?
    assert_includes @form.errors[:first_name], "is too long (maximum is 50 characters)"
    assert_includes @form.errors[:last_name], "is too long (maximum is 50 characters)"
  end

  test "should update user successfully with valid attributes" do
    new_attributes = {
      first_name: 'Updated',
      last_name: 'Name',
      email: 'updated@example.com',
      avatar_url: 'https://example.com/avatar.jpg'
    }
    
    assert @form.update(new_attributes)
    
    @user.reload
    assert_equal 'Updated', @user.first_name
    assert_equal 'Name', @user.last_name
    assert_equal 'updated@example.com', @user.email
    assert_equal 'https://example.com/avatar.jpg', @user.avatar_url
  end

  test "should not update with duplicate email" do
    other_user = users(:two)
    
    assert_not @form.update(email: other_user.email, first_name: 'Test', last_name: 'User')
    assert_includes @form.errors[:email], "is already taken"
  end
end