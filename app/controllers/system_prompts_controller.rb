# frozen_string_literal: true

class SystemPromptsController < ApplicationController
  before_action :set_system_prompt, only: [:show, :edit, :update, :destroy, :activate, :clone]
  before_action :set_workspace, only: [:index, :new, :create]

  def index
    @system_prompts = if @workspace
                        SystemPrompt.for_workspace(@workspace)
                      else
                        SystemPrompt.global
                      end
    @system_prompts = @system_prompts.order(:name, :created_at)
  end

  def show
    @version_history = @system_prompt.version_history
  end

  def new
    @system_prompt = SystemPrompt.new(workspace: @workspace)
  end

  def create
    @system_prompt = SystemPrompt.new(system_prompt_params)
    @system_prompt.workspace = @workspace
    @system_prompt.created_by = current_user if respond_to?(:current_user)

    if @system_prompt.save
      redirect_to system_prompt_path(@system_prompt), notice: 'System prompt was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @system_prompt.update(system_prompt_params)
      redirect_to system_prompt_path(@system_prompt), notice: 'System prompt was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @system_prompt.destroy
    redirect_to system_prompts_path(workspace_id: @system_prompt.workspace_id), 
                notice: 'System prompt was successfully deleted.'
  end

  def activate
    @system_prompt.activate!
    redirect_to system_prompt_path(@system_prompt), notice: 'System prompt has been activated.'
  end

  def clone
    target_workspace_id = params[:target_workspace_id]
    target_workspace = target_workspace_id.present? ? Workspace.find(target_workspace_id) : nil
    
    cloned_prompt = @system_prompt.clone!(params[:new_name], target_workspace)
    redirect_to system_prompt_path(cloned_prompt), notice: 'System prompt has been cloned.'
  end

  def diff
    @system_prompt = SystemPrompt.find(params[:id])
    @version_id = params[:version_id]
    @diff = @system_prompt.diff_with_version(@version_id)
    
    if @diff.nil?
      redirect_to system_prompt_path(@system_prompt), alert: 'Version not found.'
    end
  end

  def new_version
    @original_prompt = SystemPrompt.find(params[:id])
    @system_prompt = @original_prompt.create_new_version!
    redirect_to edit_system_prompt_path(@system_prompt), 
                notice: 'New version created. You can now edit it.'
  end

  private

  def set_system_prompt
    @system_prompt = SystemPrompt.find(params[:id])
  end

  def set_workspace
    @workspace = params[:workspace_id].present? ? Workspace.find(params[:workspace_id]) : nil
  end

  def system_prompt_params
    params_hash = params.require(:system_prompt).permit(
      :name, :description, :prompt_text, :status,
      associated_roles: [], associated_functions: [], associated_agents: []
    )
    
    # Convert textarea inputs to arrays
    %w[associated_roles associated_functions associated_agents].each do |field|
      if params[:system_prompt][field].is_a?(String)
        params_hash[field] = params[:system_prompt][field].split("\n").map(&:strip).reject(&:blank?)
      end
    end
    
    params_hash
  end
end