# frozen_string_literal: true

class WorkspaceEmbeddingSourcesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :authorize_workspace_access!
  before_action :set_embedding_source, only: [:show, :edit, :update, :destroy, :test, :refresh]

  def index
    @embedding_sources = @workspace.workspace_embedding_sources
                                  .includes(:ai_dataset, :created_by)
                                  .order(created_at: :desc)
    
    @embedding_sources = @embedding_sources.by_type(params[:type]) if params[:type].present?
    @embedding_sources = @embedding_sources.where(status: params[:status]) if params[:status].present?
    
    @available_datasets = @workspace.ai_datasets.completed.where(dataset_type: 'embedding')
  end

  def show
    @statistics = @embedding_source.statistics
    @test_result = session.delete("test_result_#{@embedding_source.id}")
  end

  def new
    @embedding_source = @workspace.workspace_embedding_sources.build
    @available_datasets = @workspace.ai_datasets.completed.where(dataset_type: 'embedding')
  end

  def create
    @embedding_source = @workspace.workspace_embedding_sources.build(embedding_source_params)
    @embedding_source.created_by = current_user

    if @embedding_source.save
      redirect_to [@workspace, @embedding_source], notice: 'Embedding source was successfully created.'
    else
      @available_datasets = @workspace.ai_datasets.completed.where(dataset_type: 'embedding')
      render :new
    end
  end

  def edit
    @available_datasets = @workspace.ai_datasets.completed.where(dataset_type: 'embedding')
  end

  def update
    if @embedding_source.update(embedding_source_params)
      redirect_to [@workspace, @embedding_source], notice: 'Embedding source was successfully updated.'
    else
      @available_datasets = @workspace.ai_datasets.completed.where(dataset_type: 'embedding')
      render :edit
    end
  end

  def destroy
    @embedding_source.destroy
    redirect_to workspace_workspace_embedding_sources_path(@workspace), 
                notice: 'Embedding source was successfully deleted.'
  end

  def test
    result = @embedding_source.test_connection
    session["test_result_#{@embedding_source.id}"] = result
    
    if result[:success]
      redirect_to [@workspace, @embedding_source], notice: 'Connection test successful.'
    else
      redirect_to [@workspace, @embedding_source], alert: "Connection test failed: #{result[:message]}"
    end
  end

  def refresh
    begin
      if @embedding_source.refresh_embeddings!
        redirect_to [@workspace, @embedding_source], notice: 'Embeddings refresh initiated.'
      else
        redirect_to [@workspace, @embedding_source], alert: 'Failed to refresh embeddings.'
      end
    rescue => error
      redirect_to [@workspace, @embedding_source], alert: "Refresh failed: #{error.message}"
    end
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find_by!(slug: params[:workspace_id])
  end

  def authorize_workspace_access!
    redirect_to root_path, alert: 'Access denied.' unless @workspace.has_member?(current_user)
  end

  def set_embedding_source
    @embedding_source = @workspace.workspace_embedding_sources.find(params[:id])
  end

  def embedding_source_params
    params.require(:workspace_embedding_source).permit(
      :name, :description, :source_type, :status, :ai_dataset_id,
      config: {}
    )
  end
end