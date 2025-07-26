# frozen_string_literal: true

require 'test_helper'

class WorkspaceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @workspace = Workspace.new(name: 'Test Workspace', created_by: @user)
  end

  test 'should be valid with valid attributes' do
    assert @workspace.valid?
  end

  test 'should require name' do
    @workspace.name = nil
    assert_not @workspace.valid?
    assert_includes @workspace.errors[:name], "can't be blank"
  end

  test 'should generate slug from name' do
    @workspace.save!
    assert_equal 'test-workspace', @workspace.slug
  end

  test 'should ensure unique slug' do
    @workspace.save!
    duplicate = Workspace.new(name: 'Test Workspace', created_by: @user)
    duplicate.save!
    assert_equal 'test-workspace-1', duplicate.slug
  end

  test 'should create creator membership on create' do
    assert_difference 'Membership.count', 1 do
      @workspace.save!
    end
    
    membership = @workspace.memberships.first
    assert_equal @user, membership.user
    assert_equal 'admin', membership.role
    assert_not_nil membership.joined_at
  end

  test 'should destroy associated memberships when destroyed' do
    @workspace.save!
    assert_difference 'Membership.count', -1 do
      @workspace.destroy
    end
  end

  test 'should check if user is admin' do
    @workspace.save!
    assert @workspace.admin?(@user)
  end

  test 'should check if user is member' do
    @workspace.save!
    assert @workspace.has_member?(@user)
  end

  test 'should return member role' do
    @workspace.save!
    assert_equal 'admin', @workspace.member_role(@user)
  end
end