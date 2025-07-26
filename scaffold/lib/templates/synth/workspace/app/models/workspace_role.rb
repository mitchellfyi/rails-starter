# frozen_string_literal: true

class WorkspaceRole < ApplicationRecord
  SYSTEM_ROLES = %w[admin member guest].freeze
  
  belongs_to :workspace
  has_many :memberships, dependent: :restrict_with_error
  has_many :users, through: :memberships
  
  validates :name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :name, uniqueness: { scope: :workspace_id }
  validates :display_name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :description, length: { maximum: 500 }
  
  # Permissions structure: { resource: [actions] }
  # Example: { 'workspace' => ['read', 'update'], 'members' => ['read', 'invite'] }
  validate :permissions_format
  
  scope :system_roles, -> { where(name: SYSTEM_ROLES) }
  scope :custom_roles, -> { where.not(name: SYSTEM_ROLES) }
  scope :by_priority, -> { order(:priority, :name) }
  
  def system_role?
    SYSTEM_ROLES.include?(name)
  end
  
  def custom_role?
    !system_role?
  end
  
  def admin?
    name == 'admin'
  end
  
  def member?
    name == 'member'
  end
  
  def guest?
    name == 'guest'
  end
  
  def can?(resource, action)
    return false if permissions.blank?
    
    resource_permissions = permissions[resource.to_s]
    return false if resource_permissions.blank?
    
    resource_permissions.include?(action.to_s)
  end
  
  def can_manage_workspace?
    can?('workspace', 'update') || admin?
  end
  
  def can_invite_members?
    can?('members', 'invite') || admin?
  end
  
  def can_remove_members?
    can?('members', 'remove') || admin?
  end
  
  def can_manage_roles?
    can?('roles', 'manage') || admin?
  end
  
  def can_impersonate?
    admin? && can?('admin', 'impersonate')
  end
  
  private
  
  def permissions_format
    return if permissions.blank?
    
    unless permissions.is_a?(Hash)
      errors.add(:permissions, 'must be a hash')
      return
    end
    
    permissions.each do |resource, actions|
      unless actions.is_a?(Array)
        errors.add(:permissions, "actions for #{resource} must be an array")
      end
      
      actions.each do |action|
        unless action.is_a?(String)
          errors.add(:permissions, "action #{action} must be a string")
        end
      end
    end
  end
end