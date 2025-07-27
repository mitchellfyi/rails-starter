# frozen_string_literal: true

class Ai::AnalyticsController < Ai::BaseController
  def index
    @usage_stats = current_workspace_runner.usage_stats(30.days.ago..Time.current)
    @daily_usage = current_workspace_runner.daily_usage(30)
    @provider_breakdown = current_workspace_runner.provider_breakdown(30.days.ago..Time.current)
    @model_breakdown = current_workspace_runner.model_breakdown(30.days.ago..Time.current)
    @trending_data = AiUsageSummary.trending_usage(current_workspace, 7)
    @efficiency_metrics = AiUsageSummary.efficiency_metrics(current_workspace, 30.days.ago..Time.current)
  end

  def usage_data
    date_range = params[:date_range] || '30'
    start_date = date_range.to_i.days.ago
    
    data = {
      daily_usage: current_workspace_runner.daily_usage(date_range.to_i),
      provider_breakdown: current_workspace_runner.provider_breakdown(start_date..Time.current),
      model_breakdown: current_workspace_runner.model_breakdown(start_date..Time.current),
      total_stats: current_workspace_runner.usage_stats(start_date..Time.current)
    }

    render json: data
  end
end