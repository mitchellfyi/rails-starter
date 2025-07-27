# frozen_string_literal: true

class Workspace < ApplicationRecord
  has_many :workspace_feature_flags, dependent: :destroy
  has_many :feature_flags, through: :workspace_feature_flags
  has_many :workspace_mcp_fetchers, dependent: :destroy
  has_many :mcp_fetchers, through: :workspace_mcp_fetchers
  has_many :ai_routing_policies, dependent: :destroy
  has_one :workspace_spending_limit, dependent: :destroy
  has_many :llm_outputs, dependent: :destroy
  has_many :llm_usage, dependent: :destroy
  
  validates :name, presence: true
  validates :monthly_ai_credit, numericality: { greater_than_or_equal_to: 0 }
  validates :current_month_usage, numericality: { greater_than_or_equal_to: 0 }

  after_initialize :set_usage_defaults, if: :new_record?
  
  def enabled_mcp_fetchers
    mcp_fetchers.joins(:workspace_mcp_fetchers)
                .where(workspace_mcp_fetchers: { enabled: true })
                .union(
                  McpFetcher.enabled.where.not(
                    id: workspace_mcp_fetchers.select(:mcp_fetcher_id)
                  )
                )
  end
  
  def mcp_fetcher_enabled?(fetcher)
    fetcher.enabled_for_workspace?(self)
  end

  # AI Usage and Billing Methods
  
  def remaining_monthly_credit
    return Float::INFINITY unless monthly_ai_credit&.> 0
    [monthly_ai_credit - current_month_usage, 0].max
  end

  def credit_exhausted?
    monthly_ai_credit&.> 0 && current_month_usage >= monthly_ai_credit
  end

  def usage_percentage
    return 0.0 unless monthly_ai_credit&.> 0
    [(current_month_usage / monthly_ai_credit * 100).round(2), 100.0].min
  end

  def would_exceed_credit?(additional_cost)
    return false unless monthly_ai_credit&.> 0
    (current_month_usage + additional_cost) > monthly_ai_credit
  end

  def add_usage!(cost)
    return unless cost > 0

    transaction do
      reset_monthly_usage_if_needed!
      increment!(:current_month_usage, cost)
      
      # If we exceed free credit and overage billing is enabled, report to Stripe
      if overage_billing_enabled? && would_exceed_credit?(0) && stripe_meter_id.present?
        report_overage_to_stripe(cost)
      end
    end
  end

  def reset_monthly_usage_if_needed!
    today = Date.current
    
    # Reset if it's a new month or first time setting usage_reset_date
    if usage_reset_date.nil? || today.beginning_of_month > usage_reset_date
      update!(
        current_month_usage: 0.0,
        usage_reset_date: today.beginning_of_month
      )
    end
  end

  def current_month_stats
    start_date = Date.current.beginning_of_month
    end_date = Date.current
    
    LlmUsage.stats_for_workspace(self, start_date: start_date, end_date: end_date)
  end

  def usage_trend(days: 30)
    LlmUsage.usage_trend_for_workspace(self, days: days)
  end

  def top_models(limit: 10)
    LlmUsage.top_models_for_workspace(self, limit: limit)
  end

  def average_daily_cost(days: 30)
    LlmUsage.average_daily_cost_for_workspace(self, days: days)
  end

  # Get usage summary for dashboard
  def usage_summary
    month_stats = current_month_stats
    
    {
      monthly_credit: monthly_ai_credit,
      current_usage: current_month_usage,
      remaining_credit: remaining_monthly_credit,
      usage_percentage: usage_percentage,
      credit_exhausted: credit_exhausted?,
      overage_billing_enabled: overage_billing_enabled?,
      this_month: {
        cost: month_stats[:total_cost],
        tokens: month_stats[:total_tokens],
        requests: month_stats[:total_requests]
      }
    }
  end

  private

  def set_usage_defaults
    self.monthly_ai_credit ||= 10.0  # $10 default monthly credit
    self.current_month_usage ||= 0.0
    self.usage_reset_date ||= Date.current.beginning_of_month
    self.overage_billing_enabled ||= false
  end

  def report_overage_to_stripe(cost)
    return unless stripe_meter_id.present?

    begin
      # Calculate overage amount (anything above the free credit)
      overage_amount = [current_month_usage - monthly_ai_credit, 0].max
      
      # Only report if there's actual overage
      if overage_amount > 0
        # This would integrate with Stripe's metered billing
        # For now, just log the overage
        Rails.logger.info "Workspace overage", {
          workspace_id: id,
          monthly_credit: monthly_ai_credit,
          current_usage: current_month_usage,
          overage_amount: overage_amount,
          new_cost: cost
        }
        
        # TODO: Integrate with Stripe metered billing API
        # stripe_client = ApiClientFactory.stripe_client
        # stripe_client.billing_meter_events.create({
        #   event_name: 'ai_usage_overage',
        #   payload: {
        #     workspace_id: id.to_s,
        #     overage_amount: overage_amount
        #   }
        # })
      end
    rescue => e
      Rails.logger.error "Failed to report overage to Stripe: #{e.message}"
      # Don't raise error to avoid breaking the main usage tracking
    end
  end
end