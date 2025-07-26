# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
  def index?
    workspace_member?
  end

  def create?
    workspace_member? && can_invite_members?
  end

  def update?
    (workspace_member? && can_manage_members?) || own_membership?
  end

  def destroy?
    (workspace_member? && can_remove_members?) || own_membership?
  end

  private

  def workspace_member?
    record.workspace.memberships.exists?(user: user)
  end

  def workspace_admin?
    record.workspace.memberships.joins(:workspace_role).exists?(user: user, workspace_roles: { name: 'admin' })
  end

  def can_invite_members?
    membership = record.workspace.memberships.find_by(user: user)
    membership&.can_invite_members?
  end

  def can_manage_members?
    membership = record.workspace.memberships.find_by(user: user)
    membership&.can_manage_workspace?
  end

  def can_remove_members?
    membership = record.workspace.memberships.find_by(user: user)
    membership&.can_remove_members?
  end

  def own_membership?
    record.user == user
  end
end