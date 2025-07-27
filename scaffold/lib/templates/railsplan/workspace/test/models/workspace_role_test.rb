# frozen_string_literal: true

require 'test_helper'

class WorkspaceRoleTest < ActiveSupport::TestCase
  def setup
    @workspace = workspaces(:one)
    @workspace_role = WorkspaceRole.new(
      workspace: @workspace,
      name: 'custom_role',
      display_name: 'Custom Role',
      description: 'A custom role for testing',
      permissions: {
        'workspace' => ['read'],
        'members' => ['read']
      }
    )
  end

  test "should be valid with valid attributes" do
    assert @workspace_role.valid?
  end

  test "should require name" do
    @workspace_role.name = nil
    assert_not @workspace_role.valid?
    assert_includes @workspace_role.errors[:name], "can't be blank"
  end

  test "should require display_name" do
    @workspace_role.display_name = nil
    assert_not @workspace_role.valid?
    assert_includes @workspace_role.errors[:display_name], "can't be blank"
  end

  test "should validate uniqueness of name within workspace" do
    @workspace_role.save!
    duplicate_role = WorkspaceRole.new(
      workspace: @workspace,
      name: 'custom_role',
      display_name: 'Another Custom Role'
    )
    assert_not duplicate_role.valid?
    assert_includes duplicate_role.errors[:name], "has already been taken"
  end

  test "should allow same name in different workspaces" do
    @workspace_role.save!
    other_workspace = Workspace.create!(name: 'Other Workspace', created_by: users(:one))
    other_role = WorkspaceRole.new(
      workspace: other_workspace,
      name: 'custom_role',
      display_name: 'Custom Role in Other Workspace'
    )
    assert other_role.valid?
  end

  test "should identify system roles correctly" do
    assert @workspace.admin_role.system_role?
    assert @workspace.member_role_obj.system_role?
    assert @workspace.guest_role.system_role?
    assert_not @workspace_role.system_role?
  end

  test "should check permissions correctly" do
    assert @workspace_role.can?('workspace', 'read')
    assert @workspace_role.can?('members', 'read')
    assert_not @workspace_role.can?('workspace', 'update')
    assert_not @workspace_role.can?('members', 'invite')
  end

  test "should validate permissions format" do
    @workspace_role.permissions = "invalid"
    assert_not @workspace_role.valid?
    assert_includes @workspace_role.errors[:permissions], "must be a hash"
  end

  test "admin role should have full permissions" do
    admin_role = @workspace.admin_role
    assert admin_role.admin?
    assert admin_role.can_manage_workspace?
    assert admin_role.can_invite_members?
    assert admin_role.can_remove_members?
    assert admin_role.can_manage_roles?
    assert admin_role.can_impersonate?
  end
end