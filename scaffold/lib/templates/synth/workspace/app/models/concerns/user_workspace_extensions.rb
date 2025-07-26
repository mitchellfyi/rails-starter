# frozen_string_literal: true

# Extensions to the User model for workspace functionality
# This should be added to the existing User model or included as a concern

module UserWorkspaceExtensions
  extend ActiveSupport::Concern

  included do
    has_many :memberships, dependent: :destroy
    has_many :workspaces, through: :memberships
    has_many :created_workspaces, class_name: 'Workspace', foreign_key: 'created_by_id', dependent: :destroy
    has_many :sent_invitations, class_name: 'Invitation', foreign_key: 'invited_by_id', dependent: :destroy
    has_many :received_invitations, class_name: 'Invitation', foreign_key: 'email', primary_key: 'email'
  end

  def admin_workspaces
    workspaces.joins(:memberships).where(memberships: { role: 'admin' })
  end

  def member_workspaces
    workspaces.joins(:memberships).where(memberships: { role: 'member' })
  end

  def guest_workspaces
    workspaces.joins(:memberships).where(memberships: { role: 'guest' })
  end

  def workspace_role(workspace)
    memberships.find_by(workspace: workspace)&.role
  end

  def admin_of?(workspace)
    memberships.exists?(workspace: workspace, role: 'admin')
  end

  def member_of?(workspace)
    memberships.exists?(workspace: workspace)
  end

  def pending_invitations
    Invitation.where(email: email).pending.valid
  end

  def can_create_workspace?
    true # Override this method to add restrictions
  end

  def default_workspace
    admin_workspaces.first || workspaces.first
  end
end

# If using this as a separate file, include it in your User model:
# class User < ApplicationRecord
#   include UserWorkspaceExtensions
#   # ... rest of your User model
# end