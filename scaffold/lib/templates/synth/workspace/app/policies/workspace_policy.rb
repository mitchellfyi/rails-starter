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
    workspace_admin?
  end

  private

  def workspace_member?
    record.memberships.exists?(user: user)
  end

  def workspace_admin?
    record.memberships.exists?(user: user, role: 'admin')
  end

  class Scope < Scope
    def resolve
      return scope.none unless user
      
      scope.joins(:memberships).where(memberships: { user: user })
    end
  end
end