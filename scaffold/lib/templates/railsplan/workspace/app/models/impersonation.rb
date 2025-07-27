# frozen_string_literal: true

class Impersonation < ApplicationRecord
  belongs_to :workspace
  belongs_to :impersonator, class_name: 'User'
  belongs_to :impersonated_user, class_name: 'User'
  
  validates :reason, presence: true, length: { maximum: 500 }
  validates :impersonator_id, uniqueness: { 
    scope: [:workspace_id, :ended_at], 
    conditions: -> { where(ended_at: nil) },
    message: 'can only have one active impersonation session per workspace'
  }
  validates :impersonated_user_id, uniqueness: {
    scope: [:workspace_id, :ended_at],
    conditions: -> { where(ended_at: nil) },
    message: 'can only be impersonated by one admin at a time per workspace'
  }
  
  validate :impersonator_has_permission
  validate :users_are_workspace_members
  validate :cannot_impersonate_self
  
  before_create :set_started_at
  
  scope :active, -> { where(ended_at: nil) }
  scope :ended, -> { where.not(ended_at: nil) }
  scope :recent, -> { order(started_at: :desc) }
  
  def active?
    ended_at.nil?
  end
  
  def ended?
    ended_at.present?
  end
  
  def duration
    return nil unless ended?
    ended_at - started_at
  end
  
  def end_impersonation!(ended_by: nil)
    return false if ended?
    
    update!(
      ended_at: Time.current,
      ended_by: ended_by
    )
  end
  
  private
  
  def set_started_at
    self.started_at = Time.current
  end
  
  def impersonator_has_permission
    return unless impersonator && workspace
    
    membership = workspace.memberships.find_by(user: impersonator)
    return errors.add(:impersonator, 'must be a member of the workspace') unless membership
    
    unless membership.can_impersonate?
      errors.add(:impersonator, 'does not have permission to impersonate users')
    end
  end
  
  def users_are_workspace_members
    if impersonator && workspace && !workspace.has_member?(impersonator)
      errors.add(:impersonator, 'must be a member of the workspace')
    end
    
    if impersonated_user && workspace && !workspace.has_member?(impersonated_user)
      errors.add(:impersonated_user, 'must be a member of the workspace')
    end
  end
  
  def cannot_impersonate_self
    if impersonator == impersonated_user
      errors.add(:impersonated_user, 'cannot impersonate yourself')
    end
  end
end