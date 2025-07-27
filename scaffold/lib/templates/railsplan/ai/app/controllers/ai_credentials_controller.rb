# frozen_string_literal: true

class AiCredentialsController < ApplicationController
  include WorkspaceScoped
  
  before_action :authenticate_user!
  before_action :set_ai_credential, only: [:show, :edit, :update, :destroy, :test_connection]
  before_action :set_ai_providers, only: [:new, :edit, :create, :update]
  
  def index
    authorize_workspace_admin!
    @ai_credentials = current_workspace.ai_credentials
                                      .includes(:ai_provider)
                                      .order(:ai_provider_id, :name)
    @grouped_credentials = @ai_credentials.group_by(&:ai_provider)
  end
  
  def show
    authorize_workspace_admin!
  end
  
  def new
    authorize_workspace_admin!
    @ai_credential = current_workspace.ai_credentials.build
    @ai_credential.temperature = 0.7
    @ai_credential.max_tokens = 4096
    @ai_credential.response_format = 'text'
  end
  
  def create
    authorize_workspace_admin!
    @ai_credential = current_workspace.ai_credentials.build(ai_credential_params)
    
    if @ai_credential.save
      redirect_to [current_workspace, @ai_credential], notice: 'AI credential was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    authorize_workspace_admin!
  end
  
  def update
    authorize_workspace_admin!
    
    if @ai_credential.update(ai_credential_params)
      redirect_to [current_workspace, @ai_credential], notice: 'AI credential was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    authorize_workspace_admin!
    @ai_credential.destroy
    redirect_to [current_workspace, :ai_credentials], notice: 'AI credential was successfully deleted.'
  end
  
  def test_connection
    authorize_workspace_admin!
    
    result = @ai_credential.test_connection
    
    if result[:success]
      flash[:notice] = "Connection test successful: #{result[:message]}"
    else
      flash[:alert] = "Connection test failed: #{result[:error]}"
    end
    
    redirect_to [current_workspace, @ai_credential]
  end
  
  private
  
  def set_ai_credential
    @ai_credential = current_workspace.ai_credentials.find(params[:id])
  end
  
  def set_ai_providers
    @ai_providers = AiProvider.active.by_priority
  end
  
  def ai_credential_params
    params.require(:ai_credential).permit(
      :ai_provider_id, :name, :api_key, :preferred_model, :temperature,
      :max_tokens, :response_format, :system_prompt, :active, :is_default,
      provider_config: {}
    )
  end
  
  def authorize_workspace_admin!
    unless current_workspace.admin?(current_user)
      redirect_to root_path, alert: 'Access denied. Workspace admin privileges required.'
    end
  end
end