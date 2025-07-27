# frozen_string_literal: true

class FallbackCredentialService
  attr_reader :user, :workspace, :provider_slug

  def initialize(user:, workspace: nil, provider_slug:)
    @user = user
    @workspace = workspace
    @provider_slug = provider_slug
  end

  # Get the best available credential for the user, including fallbacks
  def best_credential
    # Try user's own credentials first
    user_credential = AiCredential.best_for(workspace, provider_slug, allow_fallback: false)
    return wrap_credential(user_credential, :user) if user_credential

    # Fall back to admin-provided credentials
    fallback_credential = find_available_fallback
    return wrap_credential(fallback_credential, :fallback) if fallback_credential

    nil
  end

  # Record usage of a fallback credential
  def record_fallback_usage(credential, usage_count: 1)
    return false unless credential.is_a?(FallbackAiCredential)
    
    credential.record_usage(
      user: user,
      workspace: workspace,
      usage_count: usage_count
    )
  end

  # Check if user can use fallback credentials
  def can_use_fallback?
    return false unless user && workspace
    
    # Check if any fallback credentials are available
    FallbackAiCredential.available.for_provider(provider_slug).any?
  end

  # Get user's remaining usage for fallback credentials
  def remaining_fallback_usage
    fallback_credential = find_available_fallback
    return nil unless fallback_credential

    daily_usage = fallback_credential.daily_usage_for_user(user, workspace: workspace)
    remaining_daily = fallback_credential.daily_limit ? 
                      fallback_credential.daily_limit - daily_usage : 
                      Float::INFINITY

    total_usage = fallback_credential.usage_for_user(user, workspace: workspace)
    remaining_total = fallback_credential.usage_limit ? 
                      fallback_credential.usage_limit - total_usage : 
                      Float::INFINITY

    {
      credential_name: fallback_credential.name,
      daily_limit: fallback_credential.daily_limit,
      daily_usage: daily_usage,
      remaining_daily: remaining_daily,
      total_limit: fallback_credential.usage_limit,
      total_usage: total_usage,
      remaining_total: remaining_total,
      can_use: remaining_daily > 0 && remaining_total > 0
    }
  end

  # Get onboarding message for available fallback credential
  def onboarding_message
    fallback_credential = find_available_fallback
    return nil unless fallback_credential&.enabled_for_onboarding?

    fallback_credential.onboarding_message.presence || 
      default_onboarding_message(fallback_credential)
  end

  # Check if user has reached any limits
  def usage_warnings
    warnings = []
    fallback_credential = find_available_fallback
    return warnings unless fallback_credential

    usage_info = remaining_fallback_usage
    return warnings unless usage_info

    if usage_info[:daily_limit] && usage_info[:remaining_daily] <= 5
      warnings << {
        type: :daily_limit_approaching,
        message: "You have #{usage_info[:remaining_daily]} AI calls remaining today"
      }
    end

    if usage_info[:total_limit] && usage_info[:remaining_total] <= 10
      warnings << {
        type: :total_limit_approaching,
        message: "You have #{usage_info[:remaining_total]} total AI calls remaining"
      }
    end

    warnings
  end

  private

  def find_available_fallback
    @available_fallback ||= begin
      fallback = FallbackAiCredential.best_for_provider(provider_slug)
      
      if fallback&.available? && can_user_use_fallback?(fallback)
        fallback
      else
        nil
      end
    end
  end

  def can_user_use_fallback?(fallback_credential)
    return false unless fallback_credential.enabled_for_trials?

    # Check daily limit for this user
    if fallback_credential.daily_limit.present?
      daily_usage = fallback_credential.daily_usage_for_user(user, workspace: workspace)
      return false if daily_usage >= fallback_credential.daily_limit
    end

    # Check total limit for this user  
    if fallback_credential.usage_limit.present?
      total_usage = fallback_credential.usage_for_user(user, workspace: workspace)
      return false if total_usage >= fallback_credential.usage_limit
    end

    true
  end

  def wrap_credential(credential, type)
    CredentialWrapper.new(credential, type)
  end

  def default_onboarding_message(credential)
    "Try our AI features for free! You can make up to #{credential.daily_limit || 'unlimited'} AI calls per day."
  end

  # Wrapper class to provide consistent interface for both user and fallback credentials
  class CredentialWrapper
    attr_reader :credential, :type

    def initialize(credential, type)
      @credential = credential
      @type = type
    end

    def user_credential?
      type == :user
    end

    def fallback_credential?
      type == :fallback
    end

    def api_config
      credential.api_config
    end

    def full_config
      credential.full_config
    end

    def mark_used!
      if user_credential?
        credential.mark_used!
      else
        # For fallback credentials, usage is tracked separately
        true
      end
    end

    def name
      credential.name
    end

    def provider
      if credential.respond_to?(:ai_provider)
        credential.ai_provider
      else
        credential.ai_provider
      end
    end

    def to_model
      credential
    end

    # Delegate other methods to the underlying credential
    def method_missing(method, *args, &block)
      if credential.respond_to?(method)
        credential.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      credential.respond_to?(method, include_private) || super
    end
  end
end