# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true

  # Include common helpers
  include HomeHelper
  
  # Include paranoid mode security features
  include ParanoidSessionManagement if ParanoidMode.enabled?
  include ParanoidTwoFactorAuth if ParanoidMode.enabled?
  
  before_action :set_current_user
  
  private

  def current_user
    @current_user ||= session[:user_id] && User.find_by(id: session[:user_id])
  end
  
  def set_current_user
    # For development, automatically log in as admin user
    if Rails.env.development? && !current_user
      admin_user = User.find_by(admin: true)
      if admin_user
        session[:user_id] = admin_user.id
        @current_user = admin_user
      end
    end
  end

  def user_signed_in?
    current_user.present?
  end
  
  def authenticate_user!
    unless current_user
      redirect_to root_path, alert: 'Please log in to access this page.'
    end
  end
  
  # Override for paranoid session management
  def redirect_to_login
    redirect_to root_path, alert: 'Please log in to continue.'
  end
end