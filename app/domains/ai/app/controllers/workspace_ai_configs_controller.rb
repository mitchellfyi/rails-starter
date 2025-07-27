# frozen_string_literal: true

class WorkspaceAiConfigsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :authorize_workspace_admin!
  before_action :set_ai_config

  def show
    @summary = @ai_config.summary
    @embedding_sources = @workspace.workspace_embedding_sources.active.includes(:ai_dataset)
  end

  def edit
  end

  def update
    @ai_config.updated_by = current_user
    
    if @ai_config.update(ai_config_params)
      redirect_to [@workspace, @ai_config], notice: 'AI configuration was successfully updated.'
    else
      render :edit
    end
  end

  def test_rag
    query = params[:query] || 'test query'
    
    begin
      rag_result = @ai_config.build_rag_context(query)
      
      render json: {
        success: true,
        query: query,
        context: rag_result[:context],
        sources: rag_result[:sources],
        chunks_used: rag_result[:chunks_used],
        total_chunks_found: rag_result[:total_chunks_found],
        system_prompt: @ai_config.format_system_prompt(context: rag_result[:context])
      }
    rescue => error
      render json: {
        success: false,
        error: error.message
      }, status: :unprocessable_entity
    end
  end

  def reset_to_defaults
    @ai_config.assign_attributes(WorkspaceAiConfig::DEFAULTS)
    @ai_config.rag_config = {}
    @ai_config.model_config = {}
    @ai_config.tools_config = {}
    @ai_config.updated_by = current_user
    
    if @ai_config.save
      redirect_to [@workspace, @ai_config], notice: 'AI configuration reset to defaults.'
    else
      redirect_to [@workspace, @ai_config], alert: 'Failed to reset configuration.'
    end
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find_by!(slug: params[:workspace_id])
  end

  def authorize_workspace_admin!
    redirect_to root_path, alert: 'Access denied.' unless @workspace.admin?(current_user)
  end

  def set_ai_config
    @ai_config = @workspace.ai_config
  end

  def ai_config_params
    params.require(:workspace_ai_config).permit(
      :instructions, :rag_enabled, :embedding_model, :chat_model, 
      :temperature, :max_tokens,
      rag_config: {},
      model_config: {},
      tools_config: {}
    )
  end
end