# frozen_string_literal: true

class AiProvidersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_ai_provider, only: [:show, :edit, :update, :destroy]
  
  def index
    @ai_providers = AiProvider.by_priority
  end
  
  def show
  end
  
  def new
    @ai_provider = AiProvider.new
    @ai_provider.priority = AiProvider.maximum(:priority).to_i + 1
  end
  
  def create
    @ai_provider = AiProvider.new(ai_provider_params)
    
    if @ai_provider.save
      redirect_to @ai_provider, notice: 'AI provider was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @ai_provider.update(ai_provider_params)
      redirect_to @ai_provider, notice: 'AI provider was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @ai_provider.destroy
    redirect_to ai_providers_path, notice: 'AI provider was successfully deleted.'
  end
  
  private
  
  def set_ai_provider
    @ai_provider = AiProvider.find(params[:id])
  end
  
  def ai_provider_params
    params.require(:ai_provider).permit(
      :name, :description, :api_base_url, :active, :priority,
      supported_models: [], default_config: {}
    )
  end
  
  def ensure_admin!
    # This would be replaced with proper admin authorization
    # For now, assume all authenticated users can manage providers
    redirect_to root_path, alert: 'Admin access required.' unless current_user
  end
end