# frozen_string_literal: true

class ImpersonationsController < ApplicationController
  include WorkspaceScoped
  
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :set_impersonation, only: [:show, :destroy]

  def index
    authorize @workspace, :manage_members?
    @active_impersonations = @workspace.impersonations.active.includes(:impersonator, :impersonated_user).recent
    @recent_impersonations = @workspace.impersonations.ended.includes(:impersonator, :impersonated_user).recent.limit(20)
  end

  def show
    authorize @workspace, :manage_members?
  end

  def new
    authorize @workspace, :manage_members?
    
    unless current_user.can_impersonate_in?(@workspace)
      return redirect_to @workspace, alert: 'You do not have permission to impersonate users.'
    end
    
    @impersonation = @workspace.impersonations.build
    @available_users = @workspace.members.where.not(id: current_user.id).includes(:memberships)
  end

  def create
    authorize @workspace, :manage_members?
    
    unless current_user.can_impersonate_in?(@workspace)
      return redirect_to @workspace, alert: 'You do not have permission to impersonate users.'
    end
    
    @impersonation = @workspace.impersonations.build(impersonation_params)
    @impersonation.impersonator = current_user

    if @impersonation.save
      redirect_to workspace_impersonations_path(@workspace), 
                  notice: "Successfully started impersonating #{@impersonation.impersonated_user.email}."
    else
      @available_users = @workspace.members.where.not(id: current_user.id).includes(:memberships)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @workspace, :manage_members?
    
    if @impersonation.active?
      @impersonation.end_impersonation!(ended_by: 'manual')
      redirect_to workspace_impersonations_path(@workspace), 
                  notice: 'Impersonation session ended.'
    else
      redirect_to workspace_impersonations_path(@workspace), 
                  alert: 'Impersonation session is already ended.'
    end
  end

  private

  def set_workspace
    @workspace = Workspace.find_by!(slug: params[:workspace_slug])
  end

  def set_impersonation
    @impersonation = @workspace.impersonations.find(params[:id])
  end

  def impersonation_params
    params.require(:impersonation).permit(:impersonated_user_id, :reason)
  end
end