# frozen_string_literal: true

class WorkspaceRolesController < ApplicationController
  include WorkspaceScoped
  
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :set_workspace_role, only: [:show, :edit, :update, :destroy]

  def index
    authorize @workspace, :manage_members?
    @workspace_roles = @workspace.workspace_roles.by_priority.includes(:memberships)
    @system_roles = @workspace_roles.system_roles
    @custom_roles = @workspace_roles.custom_roles
  end

  def show
    authorize @workspace, :manage_members?
  end

  def new
    authorize @workspace, :manage_members?
    @workspace_role = @workspace.workspace_roles.build
  end

  def create
    authorize @workspace, :manage_members?
    @workspace_role = @workspace.workspace_roles.build(workspace_role_params)
    @workspace_role.system_role = false

    if @workspace_role.save
      redirect_to workspace_workspace_roles_path(@workspace), 
                  notice: 'Role was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @workspace, :manage_members?
    return redirect_to workspace_workspace_roles_path(@workspace), 
                       alert: 'System roles cannot be edited.' if @workspace_role.system_role?
  end

  def update
    authorize @workspace, :manage_members?
    
    if @workspace_role.system_role?
      return redirect_to workspace_workspace_roles_path(@workspace), 
                         alert: 'System roles cannot be edited.'
    end

    if @workspace_role.update(workspace_role_params)
      redirect_to workspace_workspace_roles_path(@workspace), 
                  notice: 'Role was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @workspace, :manage_members?
    
    if @workspace_role.system_role?
      return redirect_to workspace_workspace_roles_path(@workspace), 
                         alert: 'System roles cannot be deleted.'
    end
    
    if @workspace_role.memberships.any?
      return redirect_to workspace_workspace_roles_path(@workspace), 
                         alert: 'Cannot delete role that is assigned to members.'
    end

    @workspace_role.destroy
    redirect_to workspace_workspace_roles_path(@workspace), 
                notice: 'Role was successfully deleted.'
  end

  private

  def set_workspace
    @workspace = Workspace.find_by!(slug: params[:workspace_slug])
  end

  def set_workspace_role
    @workspace_role = @workspace.workspace_roles.find(params[:id])
  end

  def workspace_role_params
    params.require(:workspace_role).permit(:name, :display_name, :description, :priority, permissions: {})
  end
end