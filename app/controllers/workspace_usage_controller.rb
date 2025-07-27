# frozen_string_literal: true

class WorkspaceUsageController < ApplicationController
  before_action :set_workspace
  before_action :ensure_workspace_access

  def show
    @date_range = params[:date_range] || '30d'
    
    # Calculate date range
    end_date = Date.current
    start_date = case @date_range
                 when '7d' then 7.days.ago.to_date
                 when '30d' then 30.days.ago.to_date
                 when '90d' then 90.days.ago.to_date
                 else 30.days.ago.to_date
                 end

    # Get workspace usage summary
    @usage_summary = @workspace.usage_summary
    
    # Get detailed stats for the date range
    @usage_stats = LlmUsage.stats_for_workspace(@workspace, start_date: start_date, end_date: end_date)
    
    # Get usage trend for charts
    @usage_trend = @workspace.usage_trend(days: (end_date - start_date).to_i)
    
    # Get top models
    @top_models = @workspace.top_models(limit: 10)
    
    # Get recent high-cost requests
    @recent_expensive_requests = @workspace.llm_outputs
                                          .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                                          .where('actual_cost > ? OR estimated_cost > ?', 0.01, 0.01)
                                          .order('COALESCE(actual_cost, estimated_cost) DESC')
                                          .limit(10)
                                          .includes(:user)

    # Check if workspace is approaching limits
    @approaching_limits = check_approaching_limits
    
    # Spending limit info if available
    @spending_limit = @workspace.workspace_spending_limit
  end

  def update_credits
    return unless current_user.admin? # Only admins can update credits
    
    if @workspace.update(workspace_params)
      redirect_to workspace_usage_path(@workspace), notice: 'Credits updated successfully'
    else
      redirect_to workspace_usage_path(@workspace), alert: 'Failed to update credits'
    end
  end

  def enable_overage_billing
    return unless current_user.admin? # Only admins can enable billing
    
    # TODO: Create Stripe meter for this workspace
    # For now, just enable the flag
    @workspace.update!(overage_billing_enabled: true)
    
    redirect_to workspace_usage_path(@workspace), notice: 'Overage billing enabled'
  end

  def disable_overage_billing
    return unless current_user.admin?
    
    @workspace.update!(overage_billing_enabled: false)
    
    redirect_to workspace_usage_path(@workspace), notice: 'Overage billing disabled'
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:workspace_id] || params[:id])
  end

  def ensure_workspace_access
    # TODO: Implement proper workspace access control
    # For now, allow all authenticated users
    redirect_to root_path unless user_signed_in?
  end

  def workspace_params
    params.require(:workspace).permit(:monthly_ai_credit)
  end

  def check_approaching_limits
    summary = @workspace.usage_summary
    warnings = []

    # Check monthly credit usage
    if summary[:usage_percentage] > 80
      warnings << {
        type: 'monthly_credit',
        message: "#{summary[:usage_percentage]}% of monthly AI credit used",
        severity: summary[:usage_percentage] > 95 ? 'danger' : 'warning'
      }
    end

    # Check spending limits if configured
    if @workspace.workspace_spending_limit&.enabled?
      spending_summary = @workspace.workspace_spending_limit.spending_summary
      
      [:daily, :weekly, :monthly].each do |period|
        period_data = spending_summary[period]
        next unless period_data[:limit] && period_data[:limit] > 0
        
        percentage = (period_data[:current] / period_data[:limit] * 100).round(1)
        
        if percentage > 80
          warnings << {
            type: "#{period}_spending",
            message: "#{percentage}% of #{period} spending limit used",
            severity: percentage > 95 ? 'danger' : 'warning'
          }
        end
      end
    end

    warnings
  end
end