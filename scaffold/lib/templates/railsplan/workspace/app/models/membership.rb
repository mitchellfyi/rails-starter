# frozen_string_literal: true

class Membership < ApplicationRecord
  VALID_ROLES = %w[admin member guest].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :invited_by, class_name: 'User', foreign_key: 'invited_by_id', optional: true
  belongs_to :workspace_role

  validates :role, presence: true, inclusion: { in: VALID_ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id }
  validate :workspace_role_belongs_to_workspace

  before_validation :set_joined_at, if: -> { joined_at.blank? && user.present? }
  before_validation :sync_role_from_workspace_role, if: :workspace_role_changed?

  scope :admins, -> { joins(:workspace_role).where(workspace_roles: { name: 'admin' }) }
  scope :members, -> { joins(:workspace_role).where(workspace_roles: { name: 'member' }) }
  scope :guests, -> { joins(:workspace_role).where(workspace_roles: { name: 'guest' }) }
  scope :recent, -> { order(joined_at: :desc) }

  delegate :admin?, :member?, :guest?, :can?, :can_manage_workspace?, 
           :can_invite_members?, :can_remove_members?, :can_manage_roles?, 
           :can_impersonate?, to: :workspace_role

  def role_display_name
    workspace_role&.display_name || role&.humanize
  end

  def role_description
    workspace_role&.description
  end

  private

  def set_joined_at
    self.joined_at = Time.current
  end

  def workspace_role_belongs_to_workspace
    return unless workspace_role && workspace
    
    unless workspace_role.workspace_id == workspace.id
      errors.add(:workspace_role, 'must belong to the same workspace')
    end
  end

  def sync_role_from_workspace_role
    self.role = workspace_role&.name if workspace_role
  end
end