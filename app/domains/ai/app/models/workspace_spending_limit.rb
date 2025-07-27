# frozen_string_literal: true

class WorkspaceSpendingLimit < ApplicationRecord
  belongs_to :workspace
  belongs_to :created_by, class_name: 'User'
  belongs_to :updated_by, class_name: 'User'

  validates :workspace_id, uniqueness: true
  validates :daily_limit, :weekly_limit, :monthly_limit, 
            numericality: { greater_than: 0, allow_nil: true }
  validates :requests_per_minute, :requests_per_hour, :requests_per_day,
            numericality: { greater_than: 0, allow_nil: true }
  validate :at_least_one_limit_set

  after_initialize :set_defaults, if: :new_record?
  
  scope :enabled, -> { where(enabled: true) }
  scope :rate_limit_enabled, -> { where(rate_limit_enabled: true) }

  def notification_emails
    return [] unless super.present?
    JSON.parse(super)
  rescue JSON::ParserError
    []
  end

  def notification_emails=(value)
    super(value.is_a?(Array) ? value.to_json : value)
  end

  # Check if any spending limit is exceeded
  def exceeded?
    daily_exceeded? || weekly_exceeded? || monthly_exceeded? || rate_limit_exceeded?
  end

  # Check individual limit types
  def daily_exceeded?
    daily_limit&.> 0 && current_daily_spend >= daily_limit
  end

  def weekly_exceeded?
    weekly_limit&.> 0 && current_weekly_spend >= weekly_limit
  end

  def monthly_exceeded?
    monthly_limit&.> 0 && current_monthly_spend >= monthly_limit
  end

  # Rate limiting checks
  def rate_limit_exceeded?
    return false unless rate_limit_enabled?
    
    minute_exceeded? || hour_exceeded? || day_requests_exceeded?
  end

  def minute_exceeded?
    requests_per_minute&.> 0 && current_minute_requests >= requests_per_minute
  end

  def hour_exceeded?
    requests_per_hour&.> 0 && current_hour_requests >= requests_per_hour
  end

  def day_requests_exceeded?
    requests_per_day&.> 0 && current_day_requests >= requests_per_day
  end

  # Get remaining budget for each period
  def remaining_daily_budget
    return Float::INFINITY unless daily_limit&.> 0
    [daily_limit - current_daily_spend, 0].max
  end

  def remaining_weekly_budget
    return Float::INFINITY unless weekly_limit&.> 0
    [weekly_limit - current_weekly_spend, 0].max
  end

  def remaining_monthly_budget
    return Float::INFINITY unless monthly_limit&.> 0
    [monthly_limit - current_monthly_spend, 0].max
  end

  # Get the most restrictive remaining budget
  def remaining_budget
    [remaining_daily_budget, remaining_weekly_budget, remaining_monthly_budget].min
  end

  # Check if a cost would exceed limits
  def would_exceed?(cost)
    return false unless enabled?
    
    (daily_limit&.> 0 && (current_daily_spend + cost) > daily_limit) ||
    (weekly_limit&.> 0 && (current_weekly_spend + cost) > weekly_limit) ||
    (monthly_limit&.> 0 && (current_monthly_spend + cost) > monthly_limit)
  end

  # Add spending and update totals
  def add_spending!(cost)
    return unless cost > 0

    transaction do
      reset_periods_if_needed!
      
      increment!(:current_daily_spend, cost)
      increment!(:current_weekly_spend, cost)
      increment!(:current_monthly_spend, cost)
    end

    check_and_notify_limits!
  end

  # Add request count for rate limiting
  def add_request!
    return unless rate_limit_enabled?

    now = Time.current
    
    transaction do
      reset_request_counters_if_needed!(now)
      
      increment!(:current_minute_requests)
      increment!(:current_hour_requests)
      increment!(:current_day_requests)
      update!(last_request_time: now)
    end
  end

  # Check if a request would be rate limited
  def would_be_rate_limited?
    return false unless rate_limit_enabled?
    
    reset_request_counters_if_needed!(Time.current)
    rate_limit_exceeded?
  end

  # Reset spending periods if we've crossed date boundaries
  def reset_periods_if_needed!
    today = Date.current
    return if last_reset_date == today

    days_since_reset = last_reset_date ? (today - last_reset_date).to_i : 1

    if days_since_reset >= 1
      update!(current_daily_spend: 0.0)
    end

    if days_since_reset >= 7 || (last_reset_date && today.beginning_of_week > last_reset_date)
      update!(current_weekly_spend: 0.0)
    end

    if days_since_reset >= 30 || (last_reset_date && today.beginning_of_month > last_reset_date)
      update!(current_monthly_spend: 0.0)
    end

    update!(last_reset_date: today)
  end

  # Get spending summary
  def spending_summary
    {
      daily: {
        limit: daily_limit,
        current: current_daily_spend,
        remaining: remaining_daily_budget,
        exceeded: daily_exceeded?
      },
      weekly: {
        limit: weekly_limit,
        current: current_weekly_spend,
        remaining: remaining_weekly_budget,
        exceeded: weekly_exceeded?
      },
      monthly: {
        limit: monthly_limit,
        current: current_monthly_spend,
        remaining: remaining_monthly_budget,
        exceeded: monthly_exceeded?
      },
      rate_limiting: {
        enabled: rate_limit_enabled?,
        minute: {
          limit: requests_per_minute,
          current: current_minute_requests,
          exceeded: minute_exceeded?
        },
        hour: {
          limit: requests_per_hour,
          current: current_hour_requests,
          exceeded: hour_exceeded?
        },
        day: {
          limit: requests_per_day,
          current: current_day_requests,
          exceeded: day_requests_exceeded?
        }
      },
      overall_exceeded: exceeded?
    }
  end

  # Get recent spending trends
  def spending_trend(days: 7)
    workspace.llm_outputs
      .where(created_at: days.days.ago..Time.current)
      .where.not(actual_cost: nil)
      .group("DATE(created_at)")
      .sum(:actual_cost)
  end

  # Class method to find or create for workspace
  def self.for_workspace(workspace)
    find_by(workspace: workspace) || create!(
      workspace: workspace,
      created_by: workspace.owner || workspace.users.first,
      updated_by: workspace.owner || workspace.users.first
    )
  end

  private

  def at_least_one_limit_set
    if daily_limit.blank? && weekly_limit.blank? && monthly_limit.blank? && 
       requests_per_minute.blank? && requests_per_hour.blank? && requests_per_day.blank?
      errors.add(:base, 'At least one spending or rate limit must be set')
    end
  end

  def set_defaults
    self.last_reset_date ||= Date.current
    self.current_daily_spend ||= 0.0
    self.current_weekly_spend ||= 0.0
    self.current_monthly_spend ||= 0.0
    self.current_minute_requests ||= 0
    self.current_hour_requests ||= 0
    self.current_day_requests ||= 0
  end

  def reset_request_counters_if_needed!(now)
    return unless last_request_time
    
    # Reset minute counter if a minute has passed
    if now - last_request_time >= 1.minute
      update!(current_minute_requests: 0)
    end
    
    # Reset hour counter if an hour has passed
    if now - last_request_time >= 1.hour
      update!(current_hour_requests: 0)
    end
    
    # Reset day counter if a day has passed
    if now.beginning_of_day > last_request_time.beginning_of_day
      update!(current_day_requests: 0)
    end
  end

  def check_and_notify_limits!
    return unless notification_emails.any?

    notifications = []
    
    if daily_exceeded? && daily_limit_just_exceeded?
      notifications << { type: 'daily', limit: daily_limit, current: current_daily_spend }
    end
    
    if weekly_exceeded? && weekly_limit_just_exceeded?
      notifications << { type: 'weekly', limit: weekly_limit, current: current_weekly_spend }
    end
    
    if monthly_exceeded? && monthly_limit_just_exceeded?
      notifications << { type: 'monthly', limit: monthly_limit, current: current_monthly_spend }
    end

    notifications.each do |notification|
      SpendingLimitNotificationJob.perform_later(
        workspace_id: workspace_id,
        notification_type: notification[:type],
        limit: notification[:limit],
        current_spend: notification[:current],
        emails: notification_emails
      )
    end
  end

  def daily_limit_just_exceeded?
    daily_limit&.> 0 && current_daily_spend >= daily_limit && 
    (current_daily_spend - daily_limit) < 0.01 # Just crossed threshold
  end

  def weekly_limit_just_exceeded?
    weekly_limit&.> 0 && current_weekly_spend >= weekly_limit && 
    (current_weekly_spend - weekly_limit) < 0.01
  end

  def monthly_limit_just_exceeded?
    monthly_limit&.> 0 && current_monthly_spend >= monthly_limit && 
    (current_monthly_spend - monthly_limit) < 0.01
  end
end