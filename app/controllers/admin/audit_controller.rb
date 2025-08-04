# frozen_string_literal: true

class Admin::AuditController < Admin::BaseController
  def index
    @audit_logs = AuditLog.recent.includes(:user)
    filter_params = audit_filter_params
    
    # Apply filters using strong parameters
    @audit_logs = @audit_logs.where(action: filter_params[:action_type]) if filter_params[:action_type].present?
    @audit_logs = @audit_logs.where(resource_type: filter_params[:resource_type]) if filter_params[:resource_type].present?
    @audit_logs = @audit_logs.where(user_id: filter_params[:user_id]) if filter_params[:user_id].present?
    
    if filter_params[:start_date].present? && filter_params[:end_date].present?
      @audit_logs = @audit_logs.where(created_at: Date.parse(filter_params[:start_date])..Date.parse(filter_params[:end_date]))
    end
    
    # Search functionality
    if filter_params[:search].present?
      search_term = "%#{filter_params[:search]}%"
      @audit_logs = @audit_logs.where(
        "description ILIKE ? OR metadata::text ILIKE ?", 
        search_term, search_term
      )
    end
    
    @audit_logs = @audit_logs.page(filter_params[:page])
    
    # For filter dropdowns
    @users = User.all.order(:email) if defined?(User)
    @action_types = AuditLog.distinct.pluck(:action).compact if defined?(AuditLog)
    @resource_types = AuditLog.distinct.pluck(:resource_type).compact if defined?(AuditLog)
  end

  def show
    @audit_log = AuditLog.find(params[:id])
  end

  private

  def audit_filter_params
    params.permit(:action_type, :resource_type, :user_id, :start_date, :end_date, :search, :page)
  end
end