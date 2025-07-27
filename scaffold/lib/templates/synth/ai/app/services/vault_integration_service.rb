# frozen_string_literal: true

# Service for integrating with HashiCorp Vault
class VaultIntegrationService
  attr_reader :client, :config
  
  def initialize
    @config = {
      url: ENV['VAULT_ADDR'] || 'http://localhost:8200',
      token: ENV['VAULT_TOKEN'],
      namespace: ENV['VAULT_NAMESPACE'],
      secrets_path: ENV['VAULT_SECRETS_PATH'] || 'secret/data/ai-credentials'
    }
  end
  
  def available?
    config[:token].present? && vault_accessible?
  end
  
  def connection_status
    return { connected: false, error: 'VAULT_TOKEN not configured' } unless config[:token].present?
    
    begin
      response = make_vault_request('GET', 'sys/health')
      {
        connected: true,
        version: response.dig('version'),
        sealed: response.dig('sealed'),
        message: 'Connected to Vault'
      }
    rescue => e
      {
        connected: false,
        error: e.message
      }
    end
  end
  
  def sync_secrets_to_workspace(workspace)
    return { success: false, error: 'Vault not available' } unless available?
    
    begin
      secrets = fetch_secrets_from_vault
      imported_count = 0
      errors = []
      
      secrets.each do |secret_key, secret_data|
        begin
          credential = create_credential_from_vault_secret(workspace, secret_key, secret_data)
          imported_count += 1 if credential
        rescue => e
          errors << "Failed to import #{secret_key}: #{e.message}"
        end
      end
      
      {
        success: errors.empty?,
        synced_count: imported_count,
        errors: errors
      }
      
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
  
  def store_credential_in_vault(ai_credential)
    return { success: false, error: 'Vault not available' } unless available?
    
    begin
      secret_data = {
        provider: ai_credential.ai_provider.slug,
        api_key: ai_credential.api_key,
        model: ai_credential.preferred_model,
        temperature: ai_credential.temperature,
        max_tokens: ai_credential.max_tokens,
        response_format: ai_credential.response_format,
        workspace_id: ai_credential.workspace_id,
        created_at: ai_credential.created_at.iso8601,
        updated_at: ai_credential.updated_at.iso8601
      }
      
      secret_path = "#{config[:secrets_path]}/#{ai_credential.workspace.slug}/#{ai_credential.ai_provider.slug}/#{ai_credential.id}"
      
      response = make_vault_request('POST', secret_path, { data: secret_data })
      
      {
        success: true,
        vault_path: secret_path,
        version: response.dig('data', 'version')
      }
      
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
  
  def fetch_credential_from_vault(vault_path)
    return { success: false, error: 'Vault not available' } unless available?
    
    begin
      response = make_vault_request('GET', vault_path)
      secret_data = response.dig('data', 'data')
      
      {
        success: true,
        data: secret_data
      }
      
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
  
  private
  
  def vault_accessible?
    begin
      make_vault_request('GET', 'sys/health')
      true
    rescue
      false
    end
  end
  
  def fetch_secrets_from_vault
    secrets = {}
    
    # List secrets in the configured path
    begin
      list_response = make_vault_request('LIST', config[:secrets_path])
      secret_keys = list_response.dig('data', 'keys') || []
      
      secret_keys.each do |key|
        secret_path = "#{config[:secrets_path]}/#{key}"
        secret_response = make_vault_request('GET', secret_path)
        secrets[key] = secret_response.dig('data', 'data')
      end
      
    rescue => e
      Rails.logger.error "Failed to fetch secrets from Vault: #{e.message}"
    end
    
    secrets
  end
  
  def create_credential_from_vault_secret(workspace, secret_key, secret_data)
    provider_slug = secret_data['provider']
    provider = AiProvider.find_by(slug: provider_slug)
    
    return nil unless provider
    return nil unless secret_data['api_key'].present?
    
    # Check if credential already exists
    existing = workspace.ai_credentials.find_by(
      ai_provider: provider,
      vault_secret_key: secret_key
    )
    
    if existing
      # Update existing credential
      existing.update!(
        api_key: secret_data['api_key'],
        preferred_model: secret_data['model'] || existing.preferred_model,
        temperature: secret_data['temperature'] || existing.temperature,
        max_tokens: secret_data['max_tokens'] || existing.max_tokens,
        response_format: secret_data['response_format'] || existing.response_format,
        vault_synced_at: Time.current
      )
      return existing
    else
      # Create new credential
      credential_name = "#{provider.name} (Vault: #{secret_key})"
      
      return workspace.ai_credentials.create!(
        ai_provider: provider,
        name: credential_name,
        api_key: secret_data['api_key'],
        preferred_model: secret_data['model'] || 'gpt-3.5-turbo',
        temperature: secret_data['temperature'] || 0.7,
        max_tokens: secret_data['max_tokens'] || 4096,
        response_format: secret_data['response_format'] || 'text',
        active: true,
        vault_secret_key: secret_key,
        vault_synced_at: Time.current
      )
    end
  end
  
  def make_vault_request(method, path, body = nil)
    require 'net/http'
    require 'json'
    
    uri = URI("#{config[:url]}/v1/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = case method.upcase
             when 'GET'
               Net::HTTP::Get.new(uri)
             when 'POST'
               Net::HTTP::Post.new(uri)
             when 'LIST'
               req = Net::HTTP::Get.new(uri)
               req['X-Vault-Request'] = 'true'
               req['X-Vault-Token'] = config[:token]
               req['LIST'] = 'true'
               req
             else
               raise "Unsupported HTTP method: #{method}"
             end
    
    request['X-Vault-Token'] = config[:token]
    request['X-Vault-Namespace'] = config[:namespace] if config[:namespace].present?
    request['Content-Type'] = 'application/json'
    
    if body
      request.body = body.to_json
    end
    
    response = http.request(request)
    
    unless response.code.start_with?('2')
      raise "Vault request failed: #{response.code} - #{response.body}"
    end
    
    JSON.parse(response.body) if response.body.present?
  end
end