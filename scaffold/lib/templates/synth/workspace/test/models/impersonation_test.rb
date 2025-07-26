# frozen_string_literal: true

require 'test_helper'

class ImpersonationTest < ActiveSupport::TestCase
  def setup
    @workspace = workspaces(:one)
    @admin = users(:one)
    @user = users(:two)
    
    # Ensure admin has impersonation permissions
    admin_membership = @workspace.memberships.find_by(user: @admin)
    admin_membership.update!(workspace_role: @workspace.admin_role)
    
    # Ensure user is a member
    @workspace.memberships.create!(
      user: @user,
      workspace_role: @workspace.member_role_obj,
      role: 'member'
    ) unless @workspace.has_member?(@user)
    
    @impersonation = Impersonation.new(
      workspace: @workspace,
      impersonator: @admin,
      impersonated_user: @user,
      reason: 'Testing purposes'
    )
  end

  test "should be valid with valid attributes" do
    assert @impersonation.valid?
  end

  test "should require reason" do
    @impersonation.reason = nil
    assert_not @impersonation.valid?
    assert_includes @impersonation.errors[:reason], "can't be blank"
  end

  test "should require impersonator to have permission" do
    # Create a member without impersonation permission
    member = User.create!(email: 'member@example.com', password: 'password')
    @workspace.memberships.create!(
      user: member,
      workspace_role: @workspace.member_role_obj,
      role: 'member'
    )
    
    @impersonation.impersonator = member
    assert_not @impersonation.valid?
    assert_includes @impersonation.errors[:impersonator], "does not have permission to impersonate users"
  end

  test "should require both users to be workspace members" do
    outside_user = User.create!(email: 'outside@example.com', password: 'password')
    @impersonation.impersonated_user = outside_user
    assert_not @impersonation.valid?
    assert_includes @impersonation.errors[:impersonated_user], "must be a member of the workspace"
  end

  test "should not allow self-impersonation" do
    @impersonation.impersonated_user = @admin
    assert_not @impersonation.valid?
    assert_includes @impersonation.errors[:impersonated_user], "cannot impersonate yourself"
  end

  test "should prevent multiple active impersonations by same impersonator" do
    @impersonation.save!
    
    another_user = User.create!(email: 'another@example.com', password: 'password')
    @workspace.memberships.create!(
      user: another_user,
      workspace_role: @workspace.member_role_obj,
      role: 'member'
    )
    
    duplicate_impersonation = Impersonation.new(
      workspace: @workspace,
      impersonator: @admin,
      impersonated_user: another_user,
      reason: 'Another test'
    )
    
    assert_not duplicate_impersonation.valid?
    assert_includes duplicate_impersonation.errors[:impersonator_id], 
                    "can only have one active impersonation session per workspace"
  end

  test "should prevent multiple active impersonations of same user" do
    @impersonation.save!
    
    another_admin = User.create!(email: 'admin2@example.com', password: 'password')
    @workspace.memberships.create!(
      user: another_admin,
      workspace_role: @workspace.admin_role,
      role: 'admin'
    )
    
    duplicate_impersonation = Impersonation.new(
      workspace: @workspace,
      impersonator: another_admin,
      impersonated_user: @user,
      reason: 'Another test'
    )
    
    assert_not duplicate_impersonation.valid?
    assert_includes duplicate_impersonation.errors[:impersonated_user_id],
                    "can only be impersonated by one admin at a time per workspace"
  end

  test "should be active when created and ended when ended" do
    @impersonation.save!
    assert @impersonation.active?
    assert_not @impersonation.ended?
    
    @impersonation.end_impersonation!
    assert_not @impersonation.active?
    assert @impersonation.ended?
    assert @impersonation.ended_at.present?
  end

  test "should calculate duration correctly" do
    @impersonation.save!
    start_time = @impersonation.started_at
    
    # Simulate some time passing
    travel 1.hour do
      @impersonation.end_impersonation!
    end
    
    expected_duration = @impersonation.ended_at - start_time
    assert_equal expected_duration, @impersonation.duration
  end

  test "should set started_at on creation" do
    assert_nil @impersonation.started_at
    @impersonation.save!
    assert @impersonation.started_at.present?
    assert_in_delta Time.current, @impersonation.started_at, 1.second
  end
end