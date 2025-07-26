# frozen_string_literal: true

require 'test_helper'

class InvitationTest < ActiveSupport::TestCase
  def setup
    @workspace = workspaces(:one)
    @user = users(:one)
    @invitation = Invitation.new(
      workspace: @workspace,
      email: 'test@example.com',
      role: 'member',
      invited_by: @user
    )
  end

  test 'should be valid with valid attributes' do
    assert @invitation.valid?
  end

  test 'should require email' do
    @invitation.email = nil
    assert_not @invitation.valid?
    assert_includes @invitation.errors[:email], "can't be blank"
  end

  test 'should require valid email format' do
    @invitation.email = 'invalid-email'
    assert_not @invitation.valid?
    assert_includes @invitation.errors[:email], 'is invalid'
  end

  test 'should require role' do
    @invitation.role = nil
    assert_not @invitation.valid?
    assert_includes @invitation.errors[:role], "can't be blank"
  end

  test 'should validate role inclusion' do
    @invitation.role = 'invalid'
    assert_not @invitation.valid?
    assert_includes @invitation.errors[:role], 'is not included in the list'
  end

  test 'should generate token on validation' do
    @invitation.save!
    assert_not_nil @invitation.token
  end

  test 'should set expiration on validation' do
    @invitation.save!
    assert_not_nil @invitation.expires_at
    assert @invitation.expires_at > Time.current
  end

  test 'should be pending by default' do
    @invitation.save!
    assert @invitation.pending?
    assert_not @invitation.accepted?
  end

  test 'should accept invitation' do
    @invitation.save!
    invited_user = User.create!(email: 'test@example.com', password: 'password')
    
    assert_difference 'Membership.count', 1 do
      assert @invitation.accept!(invited_user)
    end
    
    @invitation.reload
    assert @invitation.accepted?
    assert_not_nil @invitation.accepted_at
  end

  test 'should not accept expired invitation' do
    @invitation.expires_at = 1.day.ago
    @invitation.save!
    
    invited_user = User.create!(email: 'test@example.com', password: 'password')
    assert_not @invitation.accept!(invited_user)
  end

  test 'should not accept invitation for existing member' do
    @invitation.save!
    invited_user = User.create!(email: 'test@example.com', password: 'password')
    
    # Make user already a member
    @workspace.memberships.create!(user: invited_user, role: 'member')
    
    assert_not @invitation.accept!(invited_user)
  end

  test 'should decline invitation by destroying it' do
    @invitation.save!
    
    assert_difference 'Invitation.count', -1 do
      @invitation.decline!
    end
  end
end