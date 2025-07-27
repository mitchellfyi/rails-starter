# frozen_string_literal: true

class FallbackCredentialUsage < ApplicationRecord
  belongs_to :fallback_ai_credential
  belongs_to :user
  belongs_to :workspace, optional: true
  
  validates :date, presence: true
  validates :usage_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :date, uniqueness: { scope: [:fallback_ai_credential_id, :user_id, :workspace_id] }
  
  scope :for_date, ->(date) { where(date: date) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  scope :recent, -> { order(date: :desc, last_used_at: :desc) }
  scope :current_month, -> { where(date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :this_week, -> { where(date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :today, -> { for_date(Date.current) }
  
  # Get usage statistics for a credential
  def self.stats_for_credential(credential)
    where(fallback_ai_credential: credential).group(:date).sum(:usage_count)
  end
  
  # Get usage statistics for a user
  def self.stats_for_user(user)
    where(user: user).group(:date).sum(:usage_count)
  end
  
  # Get top users by usage
  def self.top_users(limit: 10)
    joins(:user)
      .group(:user_id)
      .order('SUM(usage_count) DESC')
      .limit(limit)
      .sum(:usage_count)
  end
  
  # Get usage trends
  def self.usage_trends(days: 30)
    where(date: days.days.ago..Date.current)
      .group(:date)
      .order(:date)
      .sum(:usage_count)
  end
  
  # Check if user has reached daily limit for any credential
  def self.user_reached_daily_limit?(user, workspace: nil)
    today_usage = today.for_user(user)
    today_usage = today_usage.for_workspace(workspace) if workspace
    
    today_usage.joins(:fallback_ai_credential).any? do |usage|
      credential = usage.fallback_ai_credential
      credential.daily_limit.present? && 
        usage.usage_count >= credential.daily_limit
    end
  end
  
  def credential_name
    fallback_ai_credential.name
  end
  
  def provider_name
    fallback_ai_credential.ai_provider.name
  end
end