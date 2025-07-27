# frozen_string_literal: true

require 'test_helper'

class WorkspaceInvitationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @workspace = workspaces(:one)
    @invited_email = 'newuser@example.com'
  end

  test 'complete invitation flow for new user' do
    # Admin sends invitation
    sign_in @admin
    
    assert_difference 'Invitation.count', 1 do
      post workspace_invitations_path(@workspace), params: {
        invitation: { email: @invited_email, role: 'member' }
      }
    end
    
    invitation = Invitation.last
    assert_equal @invited_email, invitation.email
    assert_equal 'member', invitation.role
    assert_equal @admin, invitation.invited_by
    
    # Simulate invitation email would be sent
    assert_enqueued_emails 1
    
    sign_out @admin
    
    # New user visits invitation link
    get invitation_path(invitation.token)
    assert_response :success
    assert_select 'h2', "You've been invited!"
    
    # Create new user account
    new_user = User.create!(email: @invited_email, password: 'password123')
    
    # Sign in as new user
    sign_in new_user
    
    # Accept invitation
    assert_difference 'Membership.count', 1 do
      patch accept_invitation_path(invitation.token)
    end
    
    # Check invitation is accepted
    invitation.reload
    assert invitation.accepted?
    assert_not_nil invitation.accepted_at
    
    # Check membership is created
    membership = @workspace.memberships.find_by(user: new_user)
    assert_not_nil membership
    assert_equal 'member', membership.role
    assert_equal @admin, membership.invited_by
    
    # User should be redirected to workspace
    assert_redirected_to workspace_path(@workspace)
    
    # Follow redirect and check access
    follow_redirect!
    assert_response :success
    assert_select 'h1', @workspace.name
  end

  test 'invitation expiry handling' do
    expired_invitation = invitations(:expired_invitation)
    
    get invitation_path(expired_invitation.token)
    assert_response :success
    assert_select 'h3', 'Invitation Expired'
  end

  test 'invitation already accepted handling' do
    accepted_invitation = invitations(:accepted_invitation)
    
    get invitation_path(accepted_invitation.token)
    assert_response :success
    assert_select 'h3', 'Already Accepted'
  end

  test 'duplicate invitation prevention' do
    sign_in @admin
    
    # Create first invitation
    post workspace_invitations_path(@workspace), params: {
      invitation: { email: @invited_email, role: 'member' }
    }
    
    # Try to create duplicate invitation
    assert_no_difference 'Invitation.count' do
      post workspace_invitations_path(@workspace), params: {
        invitation: { email: @invited_email, role: 'admin' }
      }
    end
  end

  test 'invitation decline flow' do
    invitation = invitations(:pending_invitation)
    
    assert_difference 'Invitation.count', -1 do
      patch decline_invitation_path(invitation.token)
    end
    
    assert_redirected_to root_path
  end
end