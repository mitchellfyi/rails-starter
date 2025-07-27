# frozen_string_literal: true

class AiUsageSummaryJob < ApplicationJob
  queue_as :default

  def perform(date = nil)
    target_date = date&.to_date || Date.current

    Rails.logger.info "Starting AI usage summary job for #{target_date}"

    # Process each workspace separately
    Workspace.find_each do |workspace|
      process_workspace_summary(workspace, target_date)
    end

    # Clean up old usage data (keep last 90 days)
    cleanup_old_data

    Rails.logger.info "Completed AI usage summary job for #{target_date}"
  end

  private

  def process_workspace_summary(workspace, date)
    # Get all executions for this workspace on this date
    executions = PromptExecution.joins(:workspace)
                                .where(workspace: workspace)
                                .where(created_at: date.beginning_of_day..date.end_of_day)
                                .includes(:ai_credential, :user)

    return if executions.empty?

    # Group by credential and generate summaries
    executions.group_by(&:ai_credential).each do |credential, cred_executions|
      next unless credential  # Skip executions without credential

      summary = find_or_create_summary(workspace, credential, date)
      update_summary_stats(summary, cred_executions)
    end

    # Send optional notification to workspace admins
    send_usage_notification(workspace, date) if should_send_notification?(workspace, date)
  end

  def find_or_create_summary(workspace, credential, date)
    AiUsageSummary.find_or_create_by(
      workspace: workspace,
      ai_credential: credential,
      date: date
    ) do |summary|
      summary.requests_count = 0
      summary.tokens_used = 0
      summary.estimated_cost = 0.0
      summary.successful_requests = 0
      summary.failed_requests = 0
      summary.avg_response_time = 0.0
      summary.unique_users = 0
    end
  end

  def update_summary_stats(summary, executions)
    total_tokens = 0
    total_cost = 0.0
    successful_count = 0
    failed_count = 0
    total_response_time = 0.0
    unique_users = Set.new

    executions.each do |execution|
      # Count requests
      if execution.status == 'completed'
        successful_count += 1
        total_tokens += execution.tokens_used || 0
        
        # Calculate response time if available
        if execution.started_at && execution.completed_at
          response_time = execution.completed_at - execution.started_at
          total_response_time += response_time
        end
      else
        failed_count += 1
      end

      # Track unique users
      unique_users.add(execution.user_id) if execution.user_id

      # Estimate cost
      if execution.tokens_used&.positive?
        cost_per_token = get_cost_per_token(summary.ai_credential)
        total_cost += execution.tokens_used * cost_per_token
      end
    end

    # Update summary with calculated values
    summary.update!(
      requests_count: successful_count + failed_count,
      tokens_used: total_tokens,
      estimated_cost: total_cost,
      successful_requests: successful_count,
      failed_requests: failed_count,
      avg_response_time: successful_count > 0 ? total_response_time / successful_count : 0.0,
      unique_users: unique_users.size
    )

    Rails.logger.info "Updated summary for workspace #{summary.workspace.name}, credential #{summary.ai_credential.name}: #{summary.requests_count} requests, #{summary.tokens_used} tokens, $#{summary.estimated_cost.round(4)}"
  end

  def get_cost_per_token(credential)
    case credential.ai_provider.slug
    when 'openai'
      case credential.preferred_model
      when 'gpt-4', 'gpt-4-turbo'
        0.00006  # $0.06 per 1K tokens
      when 'gpt-3.5-turbo'
        0.000002  # $0.002 per 1K tokens
      else
        0.00003   # Default OpenAI estimate
      end
    when 'anthropic'
      case credential.preferred_model
      when 'claude-3-opus'
        0.000075  # $0.075 per 1K tokens
      when 'claude-3-sonnet'
        0.000015  # $0.015 per 1K tokens
      when 'claude-3-haiku'
        0.00000125  # $0.00125 per 1K tokens
      else
        0.000015   # Default Anthropic estimate
      end
    else
      0.00002  # Generic estimate
    end
  end

  def should_send_notification?(workspace, date)
    # Send notifications on Mondays for weekly summary
    # Or if usage exceeds threshold
    return true if date.monday?

    # Check if usage exceeded threshold (e.g., 80% of monthly limit)
    monthly_usage = get_monthly_usage(workspace, date.beginning_of_month..date.end_of_month)
    monthly_limit = workspace.ai_usage_limit || 100_000  # Default 100K tokens per month
    
    monthly_usage > (monthly_limit * 0.8)
  end

  def get_monthly_usage(workspace, date_range)
    AiUsageSummary.where(workspace: workspace, date: date_range)
                  .sum(:tokens_used)
  end

  def send_usage_notification(workspace, date)
    # Find workspace admins
    admins = workspace.workspace_users.where(role: 'admin').includes(:user)
    
    return if admins.empty?

    # Calculate summary stats
    daily_summary = calculate_daily_summary(workspace, date)
    monthly_summary = calculate_monthly_summary(workspace, date.beginning_of_month..date.end_of_month)

    # Send notification (you can customize this based on your notification system)
    admins.each do |workspace_user|
      AiUsageNotificationMailer.daily_summary(
        user: workspace_user.user,
        workspace: workspace,
        daily_summary: daily_summary,
        monthly_summary: monthly_summary,
        date: date
      ).deliver_later
    end

    Rails.logger.info "Sent AI usage notification to #{admins.count} admins for workspace #{workspace.name}"
  end

  def calculate_daily_summary(workspace, date)
    summaries = AiUsageSummary.where(workspace: workspace, date: date)
    
    {
      total_requests: summaries.sum(:requests_count),
      total_tokens: summaries.sum(:tokens_used),
      total_cost: summaries.sum(:estimated_cost),
      successful_requests: summaries.sum(:successful_requests),
      failed_requests: summaries.sum(:failed_requests),
      unique_users: summaries.sum(:unique_users),
      providers_used: summaries.joins(:ai_credential).joins(:ai_provider).pluck('ai_providers.name').uniq
    }
  end

  def calculate_monthly_summary(workspace, date_range)
    summaries = AiUsageSummary.where(workspace: workspace, date: date_range)
    
    {
      total_requests: summaries.sum(:requests_count),
      total_tokens: summaries.sum(:tokens_used),
      total_cost: summaries.sum(:estimated_cost),
      avg_daily_requests: summaries.sum(:requests_count) / date_range.count,
      avg_daily_tokens: summaries.sum(:tokens_used) / date_range.count,
      most_used_provider: summaries.joins(:ai_credential).joins(:ai_provider)
                                   .group('ai_providers.name')
                                   .sum(:requests_count)
                                   .max_by { |_, count| count }&.first
    }
  end

  def cleanup_old_data
    cutoff_date = 90.days.ago.to_date
    
    # Delete old usage summaries
    deleted_summaries = AiUsageSummary.where('date < ?', cutoff_date).delete_all
    
    # Delete old prompt executions (keep for audit)
    # Note: You may want to archive instead of delete
    deleted_executions = PromptExecution.where('created_at < ?', cutoff_date.beginning_of_day).delete_all
    
    Rails.logger.info "Cleaned up #{deleted_summaries} old usage summaries and #{deleted_executions} old executions"
  end
end