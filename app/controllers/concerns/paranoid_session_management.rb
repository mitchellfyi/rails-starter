# frozen_string_literal: true

# Session management concern for paranoid mode
module ParanoidSessionManagement
  extend ActiveSupport::Concern
  
  included do
    before_action :check_session_expiry if ParanoidMode.enabled?
    before_action :update_session_activity if ParanoidMode.enabled?
  end
  
  private
  
  def check_session_expiry
    return unless session[:last_activity_at]
    
    last_activity = Time.zone.parse(session[:last_activity_at])
    if last_activity < ParanoidMode.config.session_timeout.ago
      expire_session_with_message("Your session has expired due to inactivity.")
    end
  end
  
  def update_session_activity
    session[:last_activity_at] = Time.current.iso8601
  end
  
  def expire_session_with_message(message)
    reset_session
    flash[:alert] = message
    redirect_to_login
  end
  
  def redirect_to_login
    # Override this method in your ApplicationController to redirect to your login path
    redirect_to root_path
  end
  
  def paranoid_session_timeout_remaining
    return nil unless ParanoidMode.enabled? && session[:last_activity_at]
    
    last_activity = Time.zone.parse(session[:last_activity_at])
    timeout_at = last_activity + ParanoidMode.config.session_timeout
    [(timeout_at - Time.current).to_i, 0].max
  end
end