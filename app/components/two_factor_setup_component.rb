# frozen_string_literal: true

# Two-factor authentication setup component
class TwoFactorSetupComponent < ApplicationComponent
  def initialize(user:, **html_options)
    @user = user
    @html_options = html_options
  end

  private

  attr_reader :user, :html_options

  def qr_code_enabled?
    defined?(RQRCode)
  end

  def provisioning_uri
    return unless user.otp_secret

    issuer = Rails.application.class.module_parent_name
    "otpauth://totp/#{issuer}:#{user.email}?secret=#{user.otp_secret}&issuer=#{issuer}"
  end

  def qr_code_svg
    return unless qr_code_enabled? && provisioning_uri

    qr = RQRCode::QRCode.new(provisioning_uri)
    qr.as_svg(
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: 4,
      standalone: true,
      use_path: true
    ).html_safe
  end

  def backup_codes
    # In a real implementation, these would be generated and stored securely
    user.otp_backup_codes&.split(',') || []
  end

  def setup_steps
    [
      {
        title: 'Install an authenticator app',
        description: 'Download Google Authenticator, Authy, or another TOTP app on your phone.',
        completed: true
      },
      {
        title: 'Scan the QR code',
        description: 'Open your authenticator app and scan the QR code below.',
        completed: false
      },
      {
        title: 'Enter verification code',
        description: 'Enter the 6-digit code from your authenticator app to verify setup.',
        completed: false
      },
      {
        title: 'Save backup codes',
        description: 'Store these backup codes in a safe place. You can use them if you lose access to your phone.',
        completed: false
      }
    ]
  end
end