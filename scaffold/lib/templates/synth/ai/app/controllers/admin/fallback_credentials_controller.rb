# frozen_string_literal: true

module Admin
  class FallbackCredentialsController < ApplicationController
    before_action :authenticate_admin!
    before_action :set_credential, only: [:show, :edit, :update, :destroy, :toggle_active, :test_connection]
    
    def index
      @credentials = AiCredential.fallback.includes(:ai_provider).order(:created_at)
      @providers = AiProvider.all
    end
    
    def show
    end
    
    def new
      @credential = AiCredential.new(is_fallback: true)
      @providers = AiProvider.all
    end
    
    def create
      @credential = AiCredential.new(credential_params)
      @credential.is_fallback = true
      @credential.workspace = nil
      @credential.imported_by = current_user
      
      if @credential.save
        redirect_to admin_fallback_credentials_path, notice: 'Fallback credential created successfully.'
      else
        @providers = AiProvider.all
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
      @providers = AiProvider.all
    end
    
    def update
      if @credential.update(credential_params)
        redirect_to admin_fallback_credential_path(@credential), notice: 'Fallback credential updated successfully.'
      else
        @providers = AiProvider.all
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @credential.destroy
      redirect_to admin_fallback_credentials_path, notice: 'Fallback credential deleted successfully.'
    end
    
    def toggle_active
      @credential.update!(active: !@credential.active?)
      status = @credential.active? ? 'activated' : 'deactivated'
      redirect_to admin_fallback_credentials_path, notice: "Fallback credential #{status} successfully."
    end
    
    def test_connection
      result = @credential.test_connection
      
      if result[:success]
        redirect_to admin_fallback_credential_path(@credential), notice: 'Connection test successful!'
      else
        redirect_to admin_fallback_credential_path(@credential), alert: "Connection test failed: #{result[:error]}"
      end
    end
    
    private
    
    def set_credential
      @credential = AiCredential.fallback.find(params[:id])
    end
    
    def credential_params
      params.require(:ai_credential).permit(
        :name, :ai_provider_id, :api_key, :preferred_model, :temperature, :max_tokens,
        :response_format, :active, :fallback_usage_limit, :expires_at, :onboarding_message,
        :enabled_for_trials, provider_config: {}
      )
    end
    
    def authenticate_admin!
      # Implement your admin authentication logic here
      # For example:
      # redirect_to root_path unless current_user&.admin?
    end
  end
end