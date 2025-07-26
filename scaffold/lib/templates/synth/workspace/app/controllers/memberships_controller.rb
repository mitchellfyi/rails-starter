# frozen_string_literal: true

class MembershipsController < ApplicationController
  include WorkspaceScoped
  
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :set_membership, only: [:update, :destroy]

  def index
    authorize Membership.new(workspace: @workspace)
    @memberships = @workspace.memberships.includes(:user).recent
    @invitation = @workspace.invitations.build
  end

  def create
    @membership = @workspace.memberships.build(membership_params)
    @membership.invited_by = current_user
    authorize @membership

    # Check if user exists
    user = User.find_by(email: params[:email])
    
    if user
      @membership.user = user
      @membership.joined_at = Time.current
      
      if @membership.save
        redirect_to workspace_memberships_path(@workspace), notice: 'Member added successfully.'
      else
        redirect_to workspace_memberships_path(@workspace), alert: @membership.errors.full_messages.join(', ')
      end
    else
      # Create invitation instead
      invitation = @workspace.invitations.build(
        email: params[:email],
        role: membership_params[:role],
        invited_by: current_user
      )
      
      if invitation.save
        InvitationMailer.invite_user(invitation).deliver_later
        redirect_to workspace_memberships_path(@workspace), notice: 'Invitation sent successfully.'
      else
        redirect_to workspace_memberships_path(@workspace), alert: invitation.errors.full_messages.join(', ')
      end
    end
  end

  def update
    authorize @membership
    
    if @membership.update(membership_params)
      redirect_to workspace_memberships_path(@workspace), notice: 'Member role updated successfully.'
    else
      redirect_to workspace_memberships_path(@workspace), alert: @membership.errors.full_messages.join(', ')
    end
  end

  def destroy
    authorize @membership
    
    if @membership.user == current_user
      @membership.destroy
      redirect_to workspaces_path, notice: 'You have left the workspace.'
    else
      @membership.destroy
      redirect_to workspace_memberships_path(@workspace), notice: 'Member removed successfully.'
    end
  end

  private

  def set_workspace
    @workspace = Workspace.find_by!(slug: params[:workspace_slug])
  end

  def set_membership
    @membership = @workspace.memberships.find(params[:id])
  end

  def membership_params
    params.require(:membership).permit(:role)
  end
end