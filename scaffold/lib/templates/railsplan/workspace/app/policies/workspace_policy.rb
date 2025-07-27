# frozen_string_literal: true

class WorkspacePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (workspace_member? || workspace_admin?)
  end

  def create?
    user.present?
  end

  def update?
    workspace_admin?
  end

  def destroy?
    workspace_admin?
  end

  def manage_members?
    workspace_member? && current_membership&.can_manage_workspace?
  end

  def manage_roles?
    workspace_member? && current_membership&.can_manage_roles?
  end

  def impersonate?
    workspace_member? && current_membership&.can_impersonate?
  end

  private

  def workspace_member?
    record.memberships.exists?(user: user)
  end

  def workspace_admin?
    record.memberships.joins(:workspace_role).exists?(user: user, workspace_roles: { name: 'admin' })
  end

  def current_membership
    @current_membership ||= record.memberships.find_by(user: user)
  end

  class Scope < Scope
    def resolve
      return scope.none unless user
      
      scope.joins(:memberships).where(memberships: { user: user })
    end
  end
end