# frozen_string_literal: true

class Admin::AuditController < Admin::BaseController
  def index
    @audit_logs = AuditLog.recent.includes(:user)
    
    # Apply filters
    @audit_logs = @audit_logs.where(action: params[:action_type]) if params[:action_type].present?
    @audit_logs = @audit_logs.where(resource_type: params[:resource_type]) if params[:resource_type].present?
    @audit_logs = @audit_logs.where(user_id: params[:user_id]) if params[:user_id].present?
    
    if params[:start_date].present? && params[:end_date].present?
      @audit_logs = @audit_logs.where(created_at: Date.parse(params[:start_date])..Date.parse(params[:end_date]))
    end
    
    # Search functionality
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @audit_logs = @audit_logs.where(
        "description ILIKE ? OR metadata::text ILIKE ?", 
        search_term, search_term
      )
    end
    
    @audit_logs = @audit_logs.page(params[:page])
    
    # For filter dropdowns
    @users = User.all.order(:email) if defined?(User)
    @action_types = AuditLog.distinct.pluck(:action).compact if defined?(AuditLog)
    @resource_types = AuditLog.distinct.pluck(:resource_type).compact if defined?(AuditLog)
  end

  def show
    @audit_log = AuditLog.find(params[:id])
  end
end