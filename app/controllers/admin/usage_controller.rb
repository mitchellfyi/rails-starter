# frozen_string_literal: true

class Admin::UsageController < Admin::BaseController
  def index
    @date_range = params[:date_range] || '7d'
    @workspace_filter = params[:workspace_id]
    
    # Calculate date range
    end_date = Date.current
    start_date = case @date_range
                 when '1d' then 1.day.ago
                 when '7d' then 7.days.ago
                 when '30d' then 30.days.ago
                 when '90d' then 90.days.ago
                 else 7.days.ago
                 end

    # Base queries for the date range
    base_executions = PromptExecution.where(created_at: start_date..end_date)
    base_outputs = LLMOutput.where(created_at: start_date..end_date)

    # Apply workspace filter if specified
    if @workspace_filter.present?
      base_executions = base_executions.where(workspace_id: @workspace_filter)
      # LLMOutput doesn't have workspace_id, so we join through user's workspaces or skip filtering
    end

    # Workspace usage summary
    @workspace_stats = calculate_workspace_stats(base_executions)
    
    # Top models used
    @top_models = calculate_top_models(base_executions, base_outputs)
    
    # Daily usage data for charts
    @daily_usage = calculate_daily_usage(base_executions, start_date, end_date)
    
    # Most expensive prompts (by tokens)
    @expensive_prompts = calculate_expensive_prompts(base_executions)
    
    # Failing jobs alert data
    @failing_jobs = calculate_failing_jobs(base_executions, base_outputs)
    
    # Token usage spikes
    @token_spikes = calculate_token_spikes(base_executions)

    # Overall statistics
    @total_executions = base_executions.count
    @total_tokens = base_executions.sum(:tokens_used) || 0
    @success_rate = calculate_success_rate(base_executions)
    @avg_tokens_per_execution = @total_executions > 0 ? (@total_tokens.to_f / @total_executions).round(2) : 0
  end

  def workspace_detail
    @workspace_id = params[:workspace_id]
    @date_range = params[:date_range] || '7d'
    
    redirect_to admin_usage_index_path, alert: 'Workspace ID required' if @workspace_id.blank?
    
    # Same logic as index but filtered to specific workspace
    end_date = Date.current
    start_date = case @date_range
                 when '1d' then 1.day.ago
                 when '7d' then 7.days.ago
                 when '30d' then 30.days.ago
                 when '90d' then 90.days.ago
                 else 7.days.ago
                 end

    @executions = PromptExecution.where(workspace_id: @workspace_id, created_at: start_date..end_date)
    @daily_usage = calculate_daily_usage(@executions, start_date, end_date)
    @model_usage = @executions.group(:model_used).sum(:tokens_used)
    @total_tokens = @executions.sum(:tokens_used) || 0
    @success_rate = calculate_success_rate(@executions)
  end

  private

  def calculate_workspace_stats(executions)
    executions.joins(:workspace)
              .group('workspaces.id', 'workspaces.name')
              .select('workspaces.id, workspaces.name, 
                       COUNT(*) as execution_count,
                       SUM(tokens_used) as total_tokens,
                       AVG(tokens_used) as avg_tokens')
              .order('total_tokens DESC')
  rescue => e
    # Fallback if workspace table doesn't exist or join fails
    Rails.logger.warn "Workspace stats calculation failed: #{e.message}"
    executions.where.not(workspace_id: nil)
              .group(:workspace_id)
              .select('workspace_id, 
                       COUNT(*) as execution_count,
                       SUM(tokens_used) as total_tokens,
                       AVG(tokens_used) as avg_tokens')
              .order('total_tokens DESC')
  end

  def calculate_top_models(executions, outputs)
    # Combine data from both tables
    execution_models = executions.group(:model_used).count
    output_models = outputs.group(:model_name).count
    
    # Merge the counts
    combined_models = execution_models.merge(output_models) { |key, v1, v2| v1 + v2 }
    combined_models.sort_by { |k, v| -v }.first(10)
  end

  def calculate_daily_usage(executions, start_date, end_date)
    daily_data = {}
    
    # Initialize all dates with 0
    (start_date.to_date..end_date.to_date).each do |date|
      daily_data[date.strftime('%Y-%m-%d')] = { executions: 0, tokens: 0 }
    end
    
    # Fill in actual data
    executions.group('DATE(created_at)')
              .select('DATE(created_at) as date, COUNT(*) as count, SUM(tokens_used) as tokens')
              .each do |record|
      date_key = record.date.strftime('%Y-%m-%d')
      daily_data[date_key] = {
        executions: record.count,
        tokens: record.tokens || 0
      }
    end
    
    daily_data
  end

  def calculate_expensive_prompts(executions)
    executions.joins(:prompt_template)
              .group('prompt_templates.name', 'prompt_templates.id')
              .select('prompt_templates.name, prompt_templates.id,
                       SUM(tokens_used) as total_tokens,
                       COUNT(*) as execution_count,
                       AVG(tokens_used) as avg_tokens')
              .order('total_tokens DESC')
              .limit(10)
  rescue => e
    # Fallback if prompt_template relationship fails
    Rails.logger.warn "Expensive prompts calculation failed: #{e.message}"
    executions.where.not(tokens_used: nil)
              .group(:rendered_prompt)
              .select('rendered_prompt,
                       SUM(tokens_used) as total_tokens,
                       COUNT(*) as execution_count')
              .order('total_tokens DESC')
              .limit(10)
  end

  def calculate_failing_jobs(executions, outputs)
    failed_executions = executions.where(status: 'failed').count
    failed_outputs = outputs.where(status: 'failed').count
    
    {
      failed_executions: failed_executions,
      failed_outputs: failed_outputs,
      total_failures: failed_executions + failed_outputs,
      recent_failures: executions.where(status: 'failed', created_at: 1.hour.ago..Time.current).count
    }
  end

  def calculate_token_spikes(executions)
    # Find executions with unusually high token usage (above 95th percentile)
    token_values = executions.where.not(tokens_used: nil).pluck(:tokens_used)
    return [] if token_values.empty?
    
    percentile_95 = token_values.sort[(token_values.length * 0.95).floor]
    
    executions.where('tokens_used > ?', percentile_95)
              .order(tokens_used: :desc)
              .limit(10)
              .includes(:workspace, :prompt_template)
  end

  def calculate_success_rate(executions)
    total = executions.count
    return 0 if total == 0
    
    successful = executions.where(status: 'completed').count
    ((successful.to_f / total) * 100).round(2)
  end
end