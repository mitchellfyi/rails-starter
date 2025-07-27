# frozen_string_literal: true

class AiDatasetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :authorize_workspace_access!
  before_action :set_ai_dataset, only: [:show, :edit, :update, :destroy, :process, :download]

  def index
    @ai_datasets = @workspace.ai_datasets
                            .includes(:created_by, files_attachments: :blob)
                            .order(created_at: :desc)
    
    @ai_datasets = @ai_datasets.by_type(params[:type]) if params[:type].present?
    @ai_datasets = @ai_datasets.by_status(params[:status]) if params[:status].present?
  end

  def show
    @embedding_sources = @ai_dataset.workspace_embedding_sources.includes(:workspace)
  end

  def new
    @ai_dataset = @workspace.ai_datasets.build
  end

  def create
    @ai_dataset = @workspace.ai_datasets.build(ai_dataset_params)
    @ai_dataset.created_by = current_user

    if @ai_dataset.save
      redirect_to [@workspace, @ai_dataset], notice: 'Dataset was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @ai_dataset.update(ai_dataset_params)
      redirect_to [@workspace, @ai_dataset], notice: 'Dataset was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @ai_dataset.destroy
    redirect_to workspace_ai_datasets_path(@workspace), notice: 'Dataset was successfully deleted.'
  end

  def process
    return redirect_to [@workspace, @ai_dataset], alert: 'Cannot process dataset without files.' unless @ai_dataset.files.any?
    return redirect_to [@workspace, @ai_dataset], alert: 'Dataset is already being processed.' if @ai_dataset.processing?

    begin
      case @ai_dataset.dataset_type
      when 'embedding'
        @ai_dataset.create_embeddings!
        notice = 'Dataset processing started. Embeddings will be created.'
      when 'fine-tune'
        @ai_dataset.initiate_fine_tuning!
        notice = 'Fine-tuning process initiated.'
      end
      
      redirect_to [@workspace, @ai_dataset], notice: notice
    rescue => error
      redirect_to [@workspace, @ai_dataset], alert: "Processing failed: #{error.message}"
    end
  end

  def download
    file = @ai_dataset.files.find(params[:file_id])
    redirect_to rails_blob_path(file, disposition: 'attachment')
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find_by!(slug: params[:workspace_id])
  end

  def authorize_workspace_access!
    redirect_to root_path, alert: 'Access denied.' unless @workspace.has_member?(current_user)
  end

  def set_ai_dataset
    @ai_dataset = @workspace.ai_datasets.find(params[:id])
  end

  def ai_dataset_params
    params.require(:ai_dataset).permit(:name, :description, :dataset_type, files: [])
  end
end