# frozen_string_literal: true

# Service for validating all credentials in a workspace
class CredentialValidationService
  attr_reader :workspace
  
  def initialize(workspace)
    @workspace = workspace
  end
  
  def test_all_credentials
    results = {
      total_count: 0,
      successful_count: 0,
      failed_count: 0,
      credentials: []
    }
    
    workspace.ai_credentials.includes(:ai_provider).each do |credential|
      test_result = test_single_credential(credential)
      results[:credentials] << test_result
      results[:total_count] += 1
      
      if test_result[:success]
        results[:successful_count] += 1
      else
        results[:failed_count] += 1
      end
    end
    
    results[:success_rate] = results[:total_count] > 0 ? (results[:successful_count].to_f / results[:total_count] * 100).round(1) : 0
    
    results
  end
  
  def test_single_credential(credential)
    start_time = Time.current
    
    result = {
      credential_id: credential.id,
      credential_name: credential.name,
      provider: credential.ai_provider.name,
      provider_slug: credential.ai_provider.slug,
      external_source: credential.external_source,
      started_at: start_time
    }
    
    begin
      # Check if credential needs external sync
      if credential.needs_external_sync?
        sync_result = credential.sync_with_external_source
        if sync_result[:success]
          result[:sync_message] = sync_result[:message]
        else
          result[:sync_error] = sync_result[:error]
        end
      end
      
      # Test the credential connection
      test_service = AiProviderTestService.new(credential)
      connection_result = test_service.test_connection
      
      result.merge!(connection_result)
      
      # Add validation checks
      result[:validations] = run_credential_validations(credential)
      
    rescue => e
      result.merge!(
        success: false,
        error: e.message,
        error_class: e.class.name
      )
    ensure
      result[:completed_at] = Time.current
      result[:duration] = result[:completed_at] - start_time
    end
    
    result
  end
  
  def validate_environment_mapping
    scanner = EnvironmentScannerService.new
    detected_vars = scanner.scan_environment_variables
    
    validation_results = {
      detected_variables: detected_vars.count,
      mapped_credentials: 0,
      unmapped_variables: [],
      invalid_mappings: [],
      suggestions: []
    }
    
    # Check existing mappings
    workspace.ai_credentials.imported_from_environment.each do |credential|
      if detected_vars[credential.environment_source]
        validation_results[:mapped_credentials] += 1
        
        # Validate the mapping is still correct
        detected_data = detected_vars[credential.environment_source]
        if detected_data[:provider] != credential.ai_provider.slug
          validation_results[:invalid_mappings] << {
            credential: credential,
            issue: "Provider mismatch: credential is #{credential.ai_provider.slug} but env var suggests #{detected_data[:provider]}"
          }
        end
      else
        validation_results[:invalid_mappings] << {
          credential: credential,
          issue: "Environment variable #{credential.environment_source} is no longer available"
        }
      end
    end
    
    # Find unmapped variables
    mapped_env_sources = workspace.ai_credentials.imported_from_environment.pluck(:environment_source)
    detected_vars.each do |env_key, data|
      unless mapped_env_sources.include?(env_key)
        validation_results[:unmapped_variables] << env_key
      end
    end
    
    # Generate suggestions for unmapped variables
    validation_results[:suggestions] = scanner.suggest_credential_mappings(
      detected_vars.select { |k, v| validation_results[:unmapped_variables].include?(k) }
    )
    
    validation_results
  end
  
  def validate_external_integrations
    results = {
      vault: validate_vault_integration,
      doppler: validate_doppler_integration,
      onepassword: validate_onepassword_integration
    }
    
    results[:any_available] = results.values.any? { |r| r[:available] }
    results[:total_synced] = workspace.ai_credentials.count { |c| c.synced_from_external? }
    
    results
  end
  
  private
  
  def test_single_credential(credential)
    start_time = Time.current
    
    result = {
      credential_id: credential.id,
      credential_name: credential.name,
      provider: credential.ai_provider.name,
      provider_slug: credential.ai_provider.slug,
      external_source: credential.external_source,
      started_at: start_time
    }
    
    begin
      # Check if credential needs external sync
      if credential.needs_external_sync?
        sync_result = credential.sync_with_external_source
        if sync_result[:success]
          result[:sync_message] = sync_result[:message]
        else
          result[:sync_error] = sync_result[:error]
        end
      end
      
      # Test the credential connection
      test_service = AiProviderTestService.new(credential)
      connection_result = test_service.test_connection
      
      result.merge!(connection_result)
      
      # Add validation checks
      result[:validations] = run_credential_validations(credential)
      
    rescue => e
      result.merge!(
        success: false,
        error: e.message,
        error_class: e.class.name
      )
    ensure
      result[:completed_at] = Time.current
      result[:duration] = result[:completed_at] - start_time
    end
    
    result
  end
  
  def run_credential_validations(credential)
    validations = []
    
    # Check API key format
    scanner = EnvironmentScannerService.new
    if scanner.validate_api_key_format(credential.ai_provider.slug, credential.api_key)
      validations << { type: 'api_key_format', status: 'pass', message: 'API key format is valid' }
    else
      validations << { type: 'api_key_format', status: 'warning', message: 'API key format may be invalid' }
    end
    
    # Check model availability
    if credential.ai_provider.supports_model?(credential.preferred_model)
      validations << { type: 'model_support', status: 'pass', message: 'Model is supported by provider' }
    else
      validations << { type: 'model_support', status: 'fail', message: 'Model is not supported by provider' }
    end
    
    # Check parameter ranges
    if credential.temperature.between?(0.0, 2.0)
      validations << { type: 'temperature_range', status: 'pass', message: 'Temperature is within valid range' }
    else
      validations << { type: 'temperature_range', status: 'fail', message: 'Temperature is outside valid range (0.0-2.0)' }
    end
    
    if credential.max_tokens.between?(1, 100000)
      validations << { type: 'max_tokens_range', status: 'pass', message: 'Max tokens is within valid range' }
    else
      validations << { type: 'max_tokens_range', status: 'fail', message: 'Max tokens is outside valid range (1-100000)' }
    end
    
    # Check external sync status
    if credential.synced_from_external?
      if credential.needs_external_sync?
        validations << { type: 'external_sync', status: 'warning', message: 'Credential needs to be synced with external source' }
      else
        validations << { type: 'external_sync', status: 'pass', message: 'Credential is up to date with external source' }
      end
    end
    
    validations
  end
  
  def validate_vault_integration
    service = VaultIntegrationService.new
    status = service.connection_status
    
    {
      available: service.available?,
      connected: status[:connected],
      error: status[:error],
      synced_credentials: workspace.ai_credentials.synced_from_vault.count
    }
  end
  
  def validate_doppler_integration
    service = DopplerIntegrationService.new
    status = service.connection_status
    
    {
      available: service.available?,
      connected: status[:connected],
      error: status[:error],
      synced_credentials: workspace.ai_credentials.synced_from_doppler.count
    }
  end
  
  def validate_onepassword_integration
    service = OnePasswordIntegrationService.new
    status = service.connection_status
    
    {
      available: service.available?,
      connected: status[:connected],
      error: status[:error],
      synced_credentials: workspace.ai_credentials.synced_from_onepassword.count
    }
  end
end