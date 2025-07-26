# frozen_string_literal: true

class Workspace < ApplicationRecord
  VALID_ROLES = %w[admin member guest].freeze

  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :invitations, dependent: :destroy
  has_many :workspace_roles, dependent: :destroy
  has_many :impersonations, dependent: :destroy

  validates :name, presence: true, length: { minimum: 1, maximum: 255 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
  validates :description, length: { maximum: 1000 }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  after_create :create_creator_membership
  after_create :create_default_roles

  scope :accessible_by, ->(user) { joins(:memberships).where(memberships: { user: user }) }

  def to_param
    slug
  end

  def admin_members
    members.joins(memberships: :workspace_role).where(workspace_roles: { name: 'admin' })
  end

  def member_role(user)
    memberships.find_by(user: user)&.workspace_role&.name
  end

  def has_member?(user)
    memberships.exists?(user: user)
  end

  def admin?(user)
    memberships.joins(:workspace_role).exists?(user: user, workspace_roles: { name: 'admin' })
  end

  def member?(user)
    memberships.joins(:workspace_role).exists?(user: user, workspace_roles: { name: 'member' })
  end

  def guest?(user)
    memberships.joins(:workspace_role).exists?(user: user, workspace_roles: { name: 'guest' })
  end

  def admin_role
    workspace_roles.find_by(name: 'admin')
  end

  def member_role_obj
    workspace_roles.find_by(name: 'member')
  end

  def guest_role
    workspace_roles.find_by(name: 'guest')
  end

  def can_user?(user, resource, action)
    membership = memberships.find_by(user: user)
    return false unless membership
    
    membership.can?(resource, action)
  end

  private

  def generate_slug
    base_slug = name.parameterize
    counter = 0
    proposed_slug = base_slug

    while Workspace.exists?(slug: proposed_slug)
      counter += 1
      proposed_slug = "#{base_slug}-#{counter}"
    end

    self.slug = proposed_slug
  end

  def create_creator_membership
    admin_role = workspace_roles.find_by(name: 'admin') || create_default_roles.first
    memberships.create!(user: created_by, workspace_role: admin_role, role: 'admin', joined_at: Time.current)
  end

  def create_default_roles
    return workspace_roles if workspace_roles.any?
    
    admin_role = workspace_roles.create!(
      name: 'admin',
      display_name: 'Administrator',
      description: 'Full access to workspace settings and member management',
      system_role: true,
      priority: 0,
      permissions: {
        'workspace' => ['read', 'update', 'delete'],
        'members' => ['read', 'invite', 'remove', 'manage_roles'],
        'roles' => ['manage'],
        'admin' => ['impersonate']
      }
    )
    
    member_role = workspace_roles.create!(
      name: 'member',
      display_name: 'Member',
      description: 'Standard member with read access and collaboration features',
      system_role: true,
      priority: 1,
      permissions: {
        'workspace' => ['read'],
        'members' => ['read']
      }
    )
    
    guest_role = workspace_roles.create!(
      name: 'guest',
      display_name: 'Guest',
      description: 'Limited access for external collaborators',
      system_role: true,
      priority: 2,
      permissions: {
        'workspace' => ['read']
      }
    )
    
    [admin_role, member_role, guest_role]
  end
end