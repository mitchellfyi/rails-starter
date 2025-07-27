# frozen_string_literal: true

require "test_helper"

class UserParanoidModeTest < ActiveSupport::TestCase
  def setup
    @original_paranoid_mode = ParanoidMode.config.enabled
    @user = User.create!(
      email: "test@example.com",
      first_name: "Test",
      last_name: "User"
    )
  end
  
  def teardown
    ParanoidMode.config.enabled = @original_paranoid_mode
  end
  
  test "two factor authentication can be enabled" do
    refute @user.two_factor_enabled?
    
    @user.enable_two_factor!
    assert @user.two_factor_enabled?
    assert @user.two_factor_secret.present?
  end
  
  test "two factor authentication can be disabled" do
    @user.enable_two_factor!
    assert @user.two_factor_enabled?
    
    @user.disable_two_factor!
    refute @user.two_factor_enabled?
    assert_nil @user.two_factor_secret
    assert_equal [], @user.backup_codes
  end
  
  test "backup codes can be generated" do
    @user.enable_two_factor!
    codes = @user.generate_backup_codes!
    
    assert_equal 10, codes.length
    assert_equal 10, @user.backup_codes_remaining
    
    codes.each do |code|
      assert_match /\A[A-F0-9]{8}\z/, code
    end
  end
  
  test "backup codes can be verified and consumed" do
    @user.enable_two_factor!
    codes = @user.generate_backup_codes!
    test_code = codes.first
    
    assert @user.verify_backup_code(test_code)
    assert_equal 9, @user.backup_codes_remaining
    
    # Code should not work again
    refute @user.verify_backup_code(test_code)
    assert_equal 9, @user.backup_codes_remaining
  end
  
  test "backup codes are case insensitive" do
    @user.enable_two_factor!
    codes = @user.generate_backup_codes!
    test_code = codes.first
    
    assert @user.verify_backup_code(test_code.downcase)
    assert_equal 9, @user.backup_codes_remaining
  end
  
  test "invalid backup codes are rejected" do
    @user.enable_two_factor!
    @user.generate_backup_codes!
    
    refute @user.verify_backup_code("INVALID1")
    refute @user.verify_backup_code("")
    refute @user.verify_backup_code(nil)
    
    assert_equal 10, @user.backup_codes_remaining
  end
  
  test "QR code URI is generated correctly" do
    @user.enable_two_factor!
    uri = @user.two_factor_qr_code_uri
    
    assert uri.present?
    assert_includes uri, "otpauth://totp"
    assert_includes uri, @user.email
    assert_includes uri, "Rails%20Starter"
  end
  
  test "QR code URI returns nil when 2FA is disabled" do
    refute @user.two_factor_enabled?
    assert_nil @user.two_factor_qr_code_uri
  end
  
  # These tests only run when paranoid mode is enabled
  if ParanoidMode.enabled?
    test "sensitive attributes are encrypted in paranoid mode" do
      skip "Encryption key not configured" unless Rails.application.credentials.encryption_key
      
      ParanoidMode.config.enabled = true
      user = User.create!(
        email: "encrypted@example.com",
        first_name: "Encrypted",
        last_name: "User"
      )
      
      # Check that encrypted columns exist and are populated
      assert user.encrypted_first_name.present?
      assert user.encrypted_first_name_iv.present?
      assert user.encrypted_last_name.present?
      assert user.encrypted_last_name_iv.present?
      
      # Verify we can still read the values
      assert_equal "Encrypted", user.first_name
      assert_equal "User", user.last_name
    end
  end
end