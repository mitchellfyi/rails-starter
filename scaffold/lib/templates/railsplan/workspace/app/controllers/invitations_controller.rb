# frozen_string_literal: true

class InvitationsController < ApplicationController
  before_action :set_invitation, only: [:show, :accept, :decline]
  before_action :set_workspace, only: [:create]
  before_action :authenticate_user!, except: [:show, :accept, :decline]

  def show
    # Public action - no authentication required for viewing invitation
    if @invitation.expired?
      render :expired
    elsif @invitation.accepted?
      render :already_accepted
    end
  end

  def create
    authorize Membership.new(workspace: @workspace)
    
    @invitation = @workspace.invitations.build(invitation_params)
    @invitation.invited_by = current_user
    
    # Set workspace_role based on role parameter
    workspace_role = @workspace.workspace_roles.find_by(name: invitation_params[:role])
    if workspace_role
      @invitation.workspace_role = workspace_role
    end

    if @invitation.save
      InvitationMailer.invite_user(@invitation).deliver_later
      redirect_to workspace_memberships_path(@workspace), notice: 'Invitation sent successfully.'
    else
      redirect_to workspace_memberships_path(@workspace), alert: @invitation.errors.full_messages.join(', ')
    end
  end

  def accept
    unless @invitation.valid?
      redirect_to @invitation, alert: 'This invitation is no longer valid.'
      return
    end

    # If user is not signed in, redirect to sign in with return path
    unless user_signed_in?
      store_location_for(:user, accept_workspace_invitation_path(@invitation.workspace, @invitation))
      redirect_to new_user_session_path, notice: 'Please sign in to accept this invitation.'
      return
    end

    if @invitation.accept!(current_user)
      redirect_to @invitation.workspace, notice: 'Welcome to the workspace!'
    else
      redirect_to @invitation, alert: 'Unable to accept invitation. You may already be a member.'
    end
  end

  def decline
    @invitation.decline!
    redirect_to root_path, notice: 'Invitation declined.'
  end

  private

  def set_invitation
    @invitation = Invitation.find_by!(token: params[:id])
  end

  def set_workspace
    @workspace = Workspace.find_by!(slug: params[:workspace_slug])
  end

  def invitation_params
    params.require(:invitation).permit(:email, :role, :workspace_role_id)
  end
end