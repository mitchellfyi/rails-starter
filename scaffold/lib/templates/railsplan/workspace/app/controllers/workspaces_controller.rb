# frozen_string_literal: true

class WorkspacesController < ApplicationController
  include WorkspaceScoped
  
  before_action :authenticate_user!
  before_action :set_workspace, only: [:show, :edit, :update, :destroy]

  def index
    @workspaces = policy_scope(Workspace).includes(:memberships, :members)
  end

  def show
    authorize @workspace
    @membership = current_user.memberships.find_by(workspace: @workspace)
    @members = @workspace.memberships.includes(:user).recent
    @pending_invitations = @workspace.invitations.pending.includes(:invited_by)
  end

  def new
    @workspace = Workspace.new
    authorize @workspace
  end

  def create
    @workspace = current_user.created_workspaces.build(workspace_params)
    authorize @workspace

    if @workspace.save
      redirect_to @workspace, notice: 'Workspace was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @workspace
  end

  def update
    authorize @workspace

    if @workspace.update(workspace_params)
      redirect_to @workspace, notice: 'Workspace was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @workspace
    
    @workspace.destroy
    redirect_to workspaces_url, notice: 'Workspace was successfully deleted.'
  end

  private

  def set_workspace
    @workspace = Workspace.find_by!(slug: params[:slug])
  end

  def workspace_params
    params.require(:workspace).permit(:name, :description)
  end
end