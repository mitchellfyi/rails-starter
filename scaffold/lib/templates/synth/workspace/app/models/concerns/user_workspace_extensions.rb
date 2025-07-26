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
    has_many :impersonations_as_impersonator, class_name: 'Impersonation', foreign_key: 'impersonator_id', dependent: :destroy
    has_many :impersonations_as_impersonated, class_name: 'Impersonation', foreign_key: 'impersonated_user_id', dependent: :destroy
  end

  def admin_workspaces
    workspaces.joins(memberships: :workspace_role).where(workspace_roles: { name: 'admin' })
  end

  def member_workspaces
    workspaces.joins(memberships: :workspace_role).where(workspace_roles: { name: 'member' })
  end

  def guest_workspaces
    workspaces.joins(memberships: :workspace_role).where(workspace_roles: { name: 'guest' })
  end

  def workspace_role(workspace)
    memberships.find_by(workspace: workspace)&.workspace_role&.name
  end

  def admin_of?(workspace)
    memberships.joins(:workspace_role).exists?(workspace: workspace, workspace_roles: { name: 'admin' })
  end

  def member_of?(workspace)
    memberships.exists?(workspace: workspace)
  end

  def can_impersonate_in?(workspace)
    membership = memberships.find_by(workspace: workspace)
    membership&.can_impersonate?
  end

  def active_impersonation_in(workspace)
    impersonations_as_impersonator.active.find_by(workspace: workspace)
  end

  def being_impersonated_in?(workspace)
    impersonations_as_impersonated.active.exists?(workspace: workspace)
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