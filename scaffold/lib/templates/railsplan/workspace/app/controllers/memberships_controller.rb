# frozen_string_literal: true

class MembershipsController < ApplicationController
  include WorkspaceScoped
  
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :set_membership, only: [:update, :destroy]

  def index
    authorize Membership.new(workspace: @workspace)
    @memberships = @workspace.memberships.includes(:user, :workspace_role, :invited_by).recent
    @pending_invitations = @workspace.invitations.pending.includes(:invited_by, :workspace_role) if policy(@workspace).manage_members?
    @invitation = @workspace.invitations.build
    @available_roles = @workspace.workspace_roles.by_priority
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
      workspace_role = @workspace.workspace_roles.find(membership_params[:workspace_role_id])
      invitation = @workspace.invitations.build(
        email: params[:email],
        role: workspace_role.name,
        workspace_role: workspace_role,
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
    
    # Prevent self-demotion of last admin
    if @membership.admin? && @membership.user == current_user
      admin_count = @workspace.memberships.joins(:workspace_role).where(workspace_roles: { name: 'admin' }).count
      if admin_count == 1 && params[:membership][:workspace_role_id] != @membership.workspace_role_id.to_s
        return redirect_to workspace_memberships_path(@workspace), 
                           alert: 'Cannot remove admin role from the last administrator.'
      end
    end
    
    if @membership.update(membership_params)
      redirect_to workspace_memberships_path(@workspace), notice: 'Member role updated successfully.'
    else
      redirect_to workspace_memberships_path(@workspace), alert: @membership.errors.full_messages.join(', ')
    end
  end

  def destroy
    authorize @membership
    
    # Prevent deletion of last admin
    if @membership.admin?
      admin_count = @workspace.memberships.joins(:workspace_role).where(workspace_roles: { name: 'admin' }).count
      if admin_count == 1
        return redirect_to workspace_memberships_path(@workspace), 
                           alert: 'Cannot remove the last administrator from the workspace.'
      end
    end
    
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
    params.require(:membership).permit(:workspace_role_id)
  end
end