# frozen_string_literal: true

class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :store_request_metadata

  layout 'admin'

  private

  def ensure_admin!
    redirect_to root_path, alert: 'Access denied.' unless current_user&.admin?
  end

  def store_request_metadata
    # Store IP and user agent for audit logging
    @current_ip = request.remote_ip
    @current_user_agent = request.user_agent
  end
end