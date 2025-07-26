# frozen_string_literal: true

module Onboardable
  extend ActiveSupport::Concern

  included do
    has_one :onboarding_progress, dependent: :destroy
  end

  def start_onboarding!
    return if onboarding_progress&.complete?
    
    self.onboarding_progress ||= build_onboarding_progress
    onboarding_progress.save!
  end

  def onboarding_complete?
    onboarding_progress&.complete? || false
  end

  def onboarding_incomplete?
    !onboarding_complete?
  end

  def complete_onboarding!
    start_onboarding! unless onboarding_progress
    
    onboarding_progress.update!(
      completed_at: Time.current,
      current_step: 'complete'
    )
  end

  def skip_onboarding!
    start_onboarding! unless onboarding_progress
    onboarding_progress.skip!
  end

  def onboarding_current_step
    start_onboarding! unless onboarding_progress
    onboarding_progress.current_step
  end

  def onboarding_progress_percentage
    return 100 if onboarding_complete?
    
    onboarding_progress&.progress_percentage || 0
  end
end