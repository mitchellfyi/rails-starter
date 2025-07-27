# frozen_string_literal: true

class LlmUsage < ApplicationRecord
  belongs_to :workspace

  validates :provider, :model, :date, presence: true
  validates :prompt_tokens, :completion_tokens, :total_tokens, :request_count,
            numericality: { greater_than_or_equal_to: 0 }
  validates :cost, numericality: { greater_than_or_equal_to: 0 }
  validates :provider, :model, :date, uniqueness: { scope: :workspace_id }

  scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :for_provider, ->(provider) { where(provider: provider) }
  scope :for_model, ->(model) { where(model: model) }
  scope :recent, -> { order(date: :desc) }
  scope :by_cost, -> { order(cost: :desc) }

  # Aggregate LLMOutput records into daily usage
  def self.aggregate_for_date(date)
    # Find all LLMOutput records for the given date that haven't been aggregated
    llm_outputs = LLMOutput.where(created_at: date.beginning_of_day..date.end_of_day)
                          .where.not(workspace_id: nil)

    # Group by workspace, provider, and model
    grouped_outputs = llm_outputs.group_by do |output|
      provider = AiUsageEstimatorService.new.send(:get_provider_for_model, output.model_name)
      [output.workspace_id, provider, output.model_name]
    end

    aggregated_count = 0

    grouped_outputs.each do |(workspace_id, provider, model), outputs|
      # Calculate totals
      total_prompt_tokens = outputs.sum { |o| o.input_tokens || 0 }
      total_completion_tokens = outputs.sum { |o| o.output_tokens || 0 }
      total_cost = outputs.sum { |o| o.actual_cost || o.estimated_cost || 0.0 }
      request_count = outputs.count

      # Find or create usage record
      usage = find_or_initialize_by(
        workspace_id: workspace_id,
        provider: provider,
        model: model,
        date: date
      )

      # Update or set values
      usage.prompt_tokens = (usage.prompt_tokens || 0) + total_prompt_tokens
      usage.completion_tokens = (usage.completion_tokens || 0) + total_completion_tokens
      usage.total_tokens = usage.prompt_tokens + usage.completion_tokens
      usage.cost = (usage.cost || 0.0) + total_cost
      usage.request_count = (usage.request_count || 0) + request_count

      usage.save!
      aggregated_count += 1
    end

    Rails.logger.info "Aggregated #{aggregated_count} LLM usage records for #{date}"
    aggregated_count
  end

  # Get aggregated stats for a workspace and date range
  def self.stats_for_workspace(workspace, start_date:, end_date:)
    usage_records = for_workspace(workspace).for_date_range(start_date, end_date)
    
    {
      total_cost: usage_records.sum(:cost),
      total_tokens: usage_records.sum(:total_tokens),
      total_requests: usage_records.sum(:request_count),
      by_provider: usage_records.group(:provider).sum(:cost),
      by_model: usage_records.group(:model).sum(:cost),
      by_date: usage_records.group(:date).sum(:cost),
      daily_breakdown: usage_records.select(
        'date, SUM(cost) as daily_cost, SUM(total_tokens) as daily_tokens, SUM(request_count) as daily_requests'
      ).group(:date).order(:date)
    }
  end

  # Get top models by cost for a workspace
  def self.top_models_for_workspace(workspace, limit: 10, start_date: 30.days.ago, end_date: Date.current)
    for_workspace(workspace)
      .for_date_range(start_date, end_date)
      .group(:provider, :model)
      .select('provider, model, SUM(cost) as total_cost, SUM(total_tokens) as total_tokens, SUM(request_count) as total_requests')
      .order('total_cost DESC')
      .limit(limit)
  end

  # Get usage trends for workspace (daily totals)
  def self.usage_trend_for_workspace(workspace, days: 30)
    end_date = Date.current
    start_date = end_date - days.days

    # Ensure we have all dates represented
    date_range = (start_date..end_date).to_a
    usage_by_date = for_workspace(workspace)
                      .for_date_range(start_date, end_date)
                      .group(:date)
                      .select('date, SUM(cost) as daily_cost, SUM(total_tokens) as daily_tokens')
                      .index_by(&:date)

    date_range.map do |date|
      usage = usage_by_date[date]
      {
        date: date,
        cost: usage&.daily_cost || 0.0,
        tokens: usage&.daily_tokens || 0
      }
    end
  end

  # Calculate average daily cost for workspace
  def self.average_daily_cost_for_workspace(workspace, days: 30)
    stats = stats_for_workspace(workspace, start_date: days.days.ago.to_date, end_date: Date.current)
    return 0.0 if days == 0
    
    stats[:total_cost] / days
  end

  # Get provider breakdown as percentages
  def provider_percentage(workspace, start_date:, end_date:)
    total = self.class.for_workspace(workspace).for_date_range(start_date, end_date).sum(:cost)
    return 0.0 if total == 0.0
    
    provider_total = self.class.for_workspace(workspace)
                         .for_date_range(start_date, end_date)
                         .where(provider: provider)
                         .sum(:cost)
    
    (provider_total / total * 100).round(2)
  end

  # Class method to aggregate all pending records
  def self.aggregate_pending_usage
    # Get the last date we aggregated (or start from oldest LLMOutput)
    last_aggregated = maximum(:date) || LLMOutput.minimum(:created_at)&.to_date
    return 0 unless last_aggregated

    # Aggregate from last date up to yesterday (don't aggregate today as it's still in progress)
    start_date = last_aggregated
    end_date = Date.current - 1.day
    
    return 0 if start_date > end_date

    total_aggregated = 0
    (start_date..end_date).each do |date|
      total_aggregated += aggregate_for_date(date)
    end

    total_aggregated
  end
end