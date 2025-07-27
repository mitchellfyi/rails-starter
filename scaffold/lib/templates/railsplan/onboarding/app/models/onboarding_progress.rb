# frozen_string_literal: true

class OnboardingProgress < ApplicationRecord
  belongs_to :user

  validates :current_step, presence: true
  validates :completed_steps, presence: true

  before_validation :set_defaults, on: :create

  # Available onboarding steps
  STEPS = %w[
    welcome
    create_workspace
    invite_colleagues
    connect_billing
    connect_ai
    explore_features
    complete
  ].freeze

  def completed_step?(step)
    completed_steps.include?(step.to_s)
  end

  def mark_step_complete(step)
    return if completed_step?(step)
    
    self.completed_steps = (completed_steps + [step.to_s]).uniq
    self.current_step = next_step_after(step)
    
    if all_required_steps_completed?
      self.completed_at = Time.current
      self.current_step = 'complete'
    end
    
    save!
  end

  def skip!
    self.skipped = true
    self.completed_at = Time.current
    self.current_step = 'complete'
    save!
  end

  def complete?
    completed_at.present? || skipped?
  end

  def incomplete?
    !complete?
  end

  def next_step
    return 'complete' if complete?
    
    available_steps = determine_available_steps
    
    # Find the first step that hasn't been completed yet
    available_steps.find { |step| !completed_step?(step) } || 'complete'
  end

  def progress_percentage
    available_steps = determine_available_steps
    return 100 if complete? || available_steps.empty?
    
    completed_count = available_steps.count { |step| completed_step?(step) }
    (completed_count.to_f / available_steps.length * 100).round
  end

  private

  def set_defaults
    self.current_step ||= 'welcome'
    self.completed_steps ||= []
  end

  def next_step_after(step)
    available_steps = determine_available_steps
    current_index = available_steps.index(step.to_s)
    
    if current_index && current_index < available_steps.length - 1
      available_steps[current_index + 1]
    else
      'complete'
    end
  end

  def all_required_steps_completed?
    available_steps = determine_available_steps
    available_steps.all? { |step| completed_step?(step) }
  end

  def determine_available_steps
    detector = ModuleDetector.new
    steps = ['welcome']
    
    # Add workspace creation if workspace module is available
    if detector.workspace_module_available?
      steps << 'create_workspace'
      steps << 'invite_colleagues'
    end
    
    # Add billing step if billing module is available
    steps << 'connect_billing' if detector.billing_module_available?
    
    # Add AI step if AI module is available
    steps << 'connect_ai' if detector.ai_module_available?
    
    # Always add final steps
    steps << 'explore_features'
    
    steps
  end
end