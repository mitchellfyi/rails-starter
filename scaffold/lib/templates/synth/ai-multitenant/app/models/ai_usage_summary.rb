# frozen_string_literal: true

class AiUsageSummary < ApplicationRecord
  belongs_to :workspace
  belongs_to :ai_credential

  validates :date, presence: true, uniqueness: { scope: [:workspace, :ai_credential] }
  validates :requests_count, :tokens_used, :successful_requests, :failed_requests, :unique_users,
            numericality: { greater_than_or_equal: 0 }
  validates :estimated_cost, :avg_response_time, numericality: { greater_than_or_equal: 0.0 }

  scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, -> { where(date: 30.days.ago.to_date..Time.current.to_date) }
  scope :this_month, -> { where(date: Time.current.beginning_of_month.to_date..Time.current.to_date) }
  scope :last_month, -> { where(date: 1.month.ago.beginning_of_month.to_date..1.month.ago.end_of_month.to_date) }

  def self.total_usage_for_workspace(workspace, date_range = nil)
    scope = where(workspace: workspace)
    scope = scope.for_date_range(date_range.begin.to_date, date_range.end.to_date) if date_range
    
    {
      total_requests: scope.sum(:requests_count),
      total_tokens: scope.sum(:tokens_used),
      total_cost: scope.sum(:estimated_cost),
      successful_requests: scope.sum(:successful_requests),
      failed_requests: scope.sum(:failed_requests),
      unique_users: scope.sum(:unique_users),
      avg_response_time: scope.average(:avg_response_time)&.round(3) || 0.0
    }
  end

  def self.daily_usage_for_workspace(workspace, days = 30)
    where(workspace: workspace, date: days.days.ago.to_date..Time.current.to_date)
      .group(:date)
      .order(:date)
      .pluck(:date, :requests_count, :tokens_used, :estimated_cost, :successful_requests, :failed_requests)
      .map do |date, requests, tokens, cost, successful, failed|
        {
          date: date,
          requests_count: requests,
          tokens_used: tokens,
          estimated_cost: cost,
          successful_requests: successful,
          failed_requests: failed,
          success_rate: requests > 0 ? (successful.to_f / requests * 100).round(2) : 0.0
        }
      end
  end

  def self.provider_breakdown_for_workspace(workspace, date_range = nil)
    scope = joins(:ai_credential).joins(ai_credential: :ai_provider).where(workspace: workspace)
    scope = scope.for_date_range(date_range.begin.to_date, date_range.end.to_date) if date_range
    
    scope.group('ai_providers.name')
         .group('ai_providers.slug')
         .sum(:requests_count, :tokens_used, :estimated_cost)
         .map do |(provider_name, provider_slug), (requests, tokens, cost)|
           {
             provider_name: provider_name,
             provider_slug: provider_slug,
             requests_count: requests,
             tokens_used: tokens,
             estimated_cost: cost
           }
         end
  end

  def self.model_breakdown_for_workspace(workspace, date_range = nil)
    scope = joins(:ai_credential).where(workspace: workspace)
    scope = scope.for_date_range(date_range.begin.to_date, date_range.end.to_date) if date_range
    
    scope.group('ai_credentials.preferred_model')
         .sum(:requests_count, :tokens_used, :estimated_cost)
         .map do |model, (requests, tokens, cost)|
           {
             model: model,
             requests_count: requests,
             tokens_used: tokens,
             estimated_cost: cost
           }
         end
  end

  def self.trending_usage(workspace, days = 7)
    current_period = where(workspace: workspace, date: days.days.ago.to_date..Time.current.to_date)
    previous_period = where(workspace: workspace, date: (days * 2).days.ago.to_date..(days + 1).days.ago.to_date)
    
    current_stats = {
      requests: current_period.sum(:requests_count),
      tokens: current_period.sum(:tokens_used),
      cost: current_period.sum(:estimated_cost)
    }
    
    previous_stats = {
      requests: previous_period.sum(:requests_count),
      tokens: previous_period.sum(:tokens_used),
      cost: previous_period.sum(:estimated_cost)
    }
    
    {
      current: current_stats,
      previous: previous_stats,
      trends: {
        requests: calculate_trend(current_stats[:requests], previous_stats[:requests]),
        tokens: calculate_trend(current_stats[:tokens], previous_stats[:tokens]),
        cost: calculate_trend(current_stats[:cost], previous_stats[:cost])
      }
    }
  end

  def success_rate
    return 100.0 if requests_count == 0
    (successful_requests.to_f / requests_count * 100).round(2)
  end

  def failure_rate
    return 0.0 if requests_count == 0
    (failed_requests.to_f / requests_count * 100).round(2)
  end

  def cost_per_request
    return 0.0 if requests_count == 0
    (estimated_cost / requests_count).round(6)
  end

  def tokens_per_request
    return 0.0 if requests_count == 0
    (tokens_used.to_f / requests_count).round(2)
  end

  def provider_name
    ai_credential.ai_provider.name
  end

  def credential_name
    ai_credential.name
  end

  def self.calculate_trend(current, previous)
    return 0.0 if previous == 0
    
    change = current - previous
    percentage = (change.to_f / previous * 100).round(2)
    
    {
      change: change,
      percentage: percentage,
      direction: change > 0 ? 'up' : (change < 0 ? 'down' : 'same')
    }
  end

  # Class methods for analytics
  def self.top_users_for_workspace(workspace, date_range = nil, limit = 10)
    # This would require joining with prompt_executions to get user stats
    # Implementation depends on your specific user tracking requirements
    []
  end

  def self.peak_usage_times(workspace, date_range = nil)
    # Analyze usage patterns by hour of day
    # This would require more detailed timestamp analysis
    # Implementation depends on your specific analytics requirements
    {}
  end

  def self.efficiency_metrics(workspace, date_range = nil)
    scope = where(workspace: workspace)
    scope = scope.for_date_range(date_range.begin.to_date, date_range.end.to_date) if date_range
    
    total_tokens = scope.sum(:tokens_used)
    total_cost = scope.sum(:estimated_cost)
    total_requests = scope.sum(:requests_count)
    avg_response_time = scope.average(:avg_response_time) || 0.0
    
    {
      cost_efficiency: total_tokens > 0 ? (total_cost / total_tokens * 1000).round(6) : 0.0, # Cost per 1K tokens
      request_efficiency: total_requests > 0 ? (total_tokens.to_f / total_requests).round(2) : 0.0, # Tokens per request
      time_efficiency: avg_response_time.round(3), # Average response time
      total_requests: total_requests,
      total_tokens: total_tokens,
      total_cost: total_cost.round(4)
    }
  end

  private_class_method :calculate_trend
end