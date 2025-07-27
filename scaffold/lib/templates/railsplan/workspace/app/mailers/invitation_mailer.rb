# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  def invite_user(invitation)
    @invitation = invitation
    @workspace = invitation.workspace
    @invited_by = invitation.invited_by
    @accept_url = workspace_invitation_url(@workspace, @invitation)

    mail(
      to: @invitation.email,
      subject: "You've been invited to join #{@workspace.name}"
    )
  end
end