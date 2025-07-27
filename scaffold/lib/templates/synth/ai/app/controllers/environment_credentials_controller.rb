# frozen_string_literal: true

class EnvironmentCredentialsController < ApplicationController
  include WorkspaceScoped
  
  before_action :authenticate_user!
  before_action :authorize_workspace_admin!
  
  def index
    @env_scanner = EnvironmentScannerService.new
    @detected_vars = @env_scanner.scan_environment_variables
    @existing_mappings = current_workspace.ai_credentials.includes(:ai_provider)
    @available_providers = AiProvider.active.by_priority
  end
  
  def import_wizard
    @env_scanner = EnvironmentScannerService.new
    @detected_vars = @env_scanner.scan_environment_variables
    @import_suggestions = @env_scanner.suggest_credential_mappings(@detected_vars)
    @available_providers = AiProvider.active.by_priority
  end
  
  def import
    @import_service = EnvironmentImportService.new(current_workspace, current_user)
    
    if params[:mappings].present?
      result = @import_service.import_from_mappings(params[:mappings])
      
      if result[:success]
        redirect_to [current_workspace, :ai_credentials], 
                   notice: "Successfully imported #{result[:imported_count]} credentials."
      else
        redirect_to [current_workspace, :environment_credentials], 
                   alert: "Import failed: #{result[:errors].join(', ')}"
      end
    else
      redirect_to [current_workspace, :environment_credentials], 
                 alert: "No mappings provided for import."
    end
  end
  
  def external_secrets
    @vault_service = VaultIntegrationService.new
    @doppler_service = DopplerIntegrationService.new
    @onepassword_service = OnePasswordIntegrationService.new
    
    @vault_status = @vault_service.connection_status
    @doppler_status = @doppler_service.connection_status
    @onepassword_status = @onepassword_service.connection_status
  end
  
  def sync_vault
    @vault_service = VaultIntegrationService.new
    
    if @vault_service.available?
      result = @vault_service.sync_secrets_to_workspace(current_workspace)
      
      if result[:success]
        redirect_to [current_workspace, :environment_credentials], 
                   notice: "Successfully synced #{result[:synced_count]} secrets from Vault."
      else
        redirect_to [current_workspace, :environment_credentials], 
                   alert: "Vault sync failed: #{result[:error]}"
      end
    else
      redirect_to [current_workspace, :environment_credentials], 
                 alert: "Vault is not configured or unavailable."
    end
  end
  
  def sync_doppler
    @doppler_service = DopplerIntegrationService.new
    
    if @doppler_service.available?
      result = @doppler_service.sync_secrets_to_workspace(current_workspace)
      
      if result[:success]
        redirect_to [current_workspace, :environment_credentials], 
                   notice: "Successfully synced #{result[:synced_count]} secrets from Doppler."
      else
        redirect_to [current_workspace, :environment_credentials], 
                   alert: "Doppler sync failed: #{result[:error]}"
      end
    else
      redirect_to [current_workspace, :environment_credentials], 
                 alert: "Doppler is not configured or unavailable."
    end
  end
  
  def sync_onepassword
    @onepassword_service = OnePasswordIntegrationService.new
    
    if @onepassword_service.available?
      result = @onepassword_service.sync_secrets_to_workspace(current_workspace)
      
      if result[:success]
        redirect_to [current_workspace, :environment_credentials], 
                   notice: "Successfully synced #{result[:synced_count]} secrets from 1Password."
      else
        redirect_to [current_workspace, :environment_credentials], 
                   alert: "1Password sync failed: #{result[:error]}"
      end
    else
      redirect_to [current_workspace, :environment_credentials], 
                 alert: "1Password CLI is not configured or unavailable."
    end
  end
  
  def test_all_credentials
    @test_service = CredentialValidationService.new(current_workspace)
    @test_results = @test_service.test_all_credentials
    
    render partial: 'test_results', locals: { test_results: @test_results }
  end
  
  private
  
  def authorize_workspace_admin!
    unless current_workspace.admin?(current_user)
      redirect_to root_path, alert: 'Access denied. Workspace admin privileges required.'
    end
  end
end