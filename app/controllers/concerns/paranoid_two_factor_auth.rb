# frozen_string_literal: true

# Two-factor authentication enforcement for admin users in paranoid mode
module ParanoidTwoFactorAuth
  extend ActiveSupport::Concern
  
  included do
    before_action :enforce_admin_2fa if ParanoidMode.enabled?
  end
  
  private
  
  def enforce_admin_2fa
    return unless current_user&.admin?
    return unless ParanoidMode.config.admin_2fa_required
    return if session[:admin_2fa_verified]
    return if params[:controller] == 'admin/two_factor_auth' # Allow access to 2FA setup/verification
    
    unless current_user.two_factor_enabled?
      flash[:alert] = "Two-factor authentication is required for admin accounts."
      redirect_to admin_two_factor_setup_path
      return
    end
    
    unless session[:admin_2fa_verified]
      flash[:alert] = "Please verify your two-factor authentication."
      redirect_to admin_two_factor_verify_path
    end
  end
  
  def verify_admin_2fa_token(token)
    return false unless current_user&.admin?
    return false unless current_user.two_factor_enabled?
    
    totp = ROTP::TOTP.new(current_user.two_factor_secret)
    verified = totp.verify(token, drift_behind: 30, drift_ahead: 30)
    
    if verified
      session[:admin_2fa_verified] = true
      session[:admin_2fa_verified_at] = Time.current.iso8601
    end
    
    verified
  end
  
  def reset_admin_2fa_session
    session.delete(:admin_2fa_verified)
    session.delete(:admin_2fa_verified_at)
  end
  
  def admin_2fa_verified?
    return false unless current_user&.admin?
    return true unless ParanoidMode.config.admin_2fa_required
    
    verified_at = session[:admin_2fa_verified_at]
    return false unless verified_at && session[:admin_2fa_verified]
    
    # Re-verify 2FA every hour in paranoid mode
    Time.zone.parse(verified_at) > 1.hour.ago
  end
end