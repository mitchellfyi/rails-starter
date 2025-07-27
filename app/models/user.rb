# frozen_string_literal: true

class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  # Serialization for backup codes
  serialize :backup_codes, coder: JSON
  
  # Encrypted attributes for paranoid mode
  if ParanoidMode.enabled?
    # Generate or retrieve a 32-byte encryption key
    encryption_key = Rails.application.credentials.encryption_key&.byteslice(0, 32) || 
                     ENV['RAILS_ENCRYPTION_KEY']&.byteslice(0, 32) || 
                     'development_key_32_bytes_long___'
    
    attr_encrypted :first_name, 
      key: encryption_key,
      algorithm: 'aes-256-gcm'
    attr_encrypted :last_name, 
      key: encryption_key,
      algorithm: 'aes-256-gcm'
    attr_encrypted :two_factor_secret, 
      key: encryption_key,
      algorithm: 'aes-256-gcm'
  end
  
  def admin?
    admin == true
  end
  
  def full_name
    [first_name, last_name].compact.join(' ').presence || email
  end
  
  # Two-factor authentication methods for paranoid mode
  def two_factor_enabled?
    two_factor_secret.present?
  end
  
  def enable_two_factor!
    self.two_factor_secret = ROTP::Base32.random if two_factor_secret.blank?
    save!
  end
  
  def disable_two_factor!
    self.two_factor_secret = nil
    self.backup_codes = []
    save!
  end
  
  def two_factor_qr_code_uri(issuer = "Rails Starter")
    return nil unless two_factor_enabled?
    
    totp = ROTP::TOTP.new(two_factor_secret, issuer: issuer)
    totp.provisioning_uri(email)
  end
  
  def generate_backup_codes!
    codes = 10.times.map { SecureRandom.hex(4).upcase }
    update!(backup_codes: codes)
    codes
  end
  
  def verify_backup_code(code)
    return false unless backup_codes.include?(code.upcase)
    
    codes = backup_codes.dup
    codes.delete(code.upcase)
    update!(backup_codes: codes)
    true
  end
  
  def backup_codes_remaining
    backup_codes&.length || 0
  end
end