# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
  def index?
    workspace_member?
  end

  def create?
    workspace_admin?
  end

  def update?
    workspace_admin? || own_membership?
  end

  def destroy?
    workspace_admin? || own_membership?
  end

  private

  def workspace_member?
    record.workspace.memberships.exists?(user: user)
  end

  def workspace_admin?
    record.workspace.memberships.exists?(user: user, role: 'admin')
  end

  def own_membership?
    record.user == user
  end
end