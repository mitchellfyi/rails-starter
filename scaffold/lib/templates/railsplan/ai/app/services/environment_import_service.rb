# frozen_string_literal: true

# Service for importing environment variables into AiCredential records
class EnvironmentImportService
  attr_reader :workspace, :user, :errors
  
  def initialize(workspace, user)
    @workspace = workspace
    @user = user
    @errors = []
  end
  
  def import_from_mappings(mappings)
    imported_count = 0
    @errors = []
    
    mappings.each do |mapping|
      next unless mapping[:enabled] == '1' || mapping[:enabled] == true
      
      begin
        result = create_credential_from_mapping(mapping)
        imported_count += 1 if result
      rescue => e
        @errors << "Failed to import #{mapping[:name]}: #{e.message}"
      end
    end
    
    {
      success: @errors.empty?,
      imported_count: imported_count,
      errors: @errors
    }
  end
  
  def import_from_env_key(env_key, provider_id, credential_name = nil)
    provider = AiProvider.find(provider_id)
    api_key_value = ENV[env_key]
    
    unless api_key_value.present?
      raise "Environment variable #{env_key} is not set or empty"
    end
    
    scanner = EnvironmentScannerService.new
    unless scanner.validate_api_key_format(provider.slug, api_key_value)
      raise "API key format appears invalid for #{provider.name}"
    end
    
    credential_name ||= "#{provider.name} (#{env_key})"
    
    # Check for existing credential with same name
    existing = workspace.ai_credentials.find_by(ai_provider: provider, name: credential_name)
    if existing
      credential_name = "#{credential_name} (#{Time.current.strftime('%Y%m%d%H%M')})"
    end
    
    ai_credential = workspace.ai_credentials.create!(
      ai_provider: provider,
      name: credential_name,
      api_key: api_key_value,
      preferred_model: suggest_default_model(provider),
      temperature: 0.7,
      max_tokens: 4096,
      response_format: 'text',
      active: true,
      environment_source: env_key,
      imported_at: Time.current,
      imported_by: user
    )
    
    # Test the credential immediately after import
    test_result = ai_credential.test_connection
    unless test_result[:success]
      Rails.logger.warn "Imported credential #{ai_credential.id} failed connection test: #{test_result[:error]}"
    end
    
    ai_credential
  end
  
  def bulk_import_detected_variables
    scanner = EnvironmentScannerService.new
    detected_vars = scanner.scan_environment_variables
    suggestions = scanner.suggest_credential_mappings(detected_vars)
    
    imported_count = 0
    @errors = []
    
    suggestions.each do |suggestion|
      begin
        env_key = suggestion[:env_key]
        api_key_value = get_env_value(env_key, detected_vars[env_key][:source])
        
        next unless api_key_value.present?
        
        ai_credential = workspace.ai_credentials.create!(
          ai_provider: suggestion[:provider],
          name: suggestion[:suggested_name],
          api_key: api_key_value,
          preferred_model: suggestion[:suggested_model],
          temperature: 0.7,
          max_tokens: 4096,
          response_format: 'text',
          active: true,
          environment_source: env_key,
          imported_at: Time.current,
          imported_by: user
        )
        
        imported_count += 1
        
      rescue => e
        @errors << "Failed to import #{suggestion[:suggested_name]}: #{e.message}"
      end
    end
    
    {
      success: @errors.empty?,
      imported_count: imported_count,
      errors: @errors
    }
  end
  
  private
  
  def create_credential_from_mapping(mapping)
    provider = AiProvider.find(mapping[:provider_id])
    env_key = mapping[:env_key]
    
    # Get the actual API key value
    api_key_value = get_env_value(env_key, mapping[:env_source])
    
    unless api_key_value.present?
      raise "Environment variable #{env_key} is not set or empty"
    end
    
    # Validate API key format
    scanner = EnvironmentScannerService.new
    unless scanner.validate_api_key_format(provider.slug, api_key_value)
      Rails.logger.warn "API key format validation failed for #{provider.name}: #{env_key}"
    end
    
    # Create the credential
    ai_credential = workspace.ai_credentials.create!(
      ai_provider: provider,
      name: mapping[:name],
      api_key: api_key_value,
      preferred_model: mapping[:model] || suggest_default_model(provider),
      temperature: mapping[:temperature]&.to_f || 0.7,
      max_tokens: mapping[:max_tokens]&.to_i || 4096,
      response_format: mapping[:response_format] || 'text',
      active: true,
      environment_source: env_key,
      imported_at: Time.current,
      imported_by: user
    )
    
    # Test the credential
    if mapping[:test_immediately] == '1' || mapping[:test_immediately] == true
      test_result = ai_credential.test_connection
      unless test_result[:success]
        Rails.logger.warn "Imported credential #{ai_credential.id} failed connection test: #{test_result[:error]}"
      end
    end
    
    ai_credential
  end
  
  def get_env_value(env_key, source)
    # First try environment variables
    if ENV[env_key].present?
      return ENV[env_key]
    end
    
    # Then try .env files if source indicates file location
    if source.include?(':')
      file_path, line_number = source.split(':')
      return parse_env_file_value(file_path, env_key)
    end
    
    nil
  end
  
  def parse_env_file_value(file_path, env_key)
    return nil unless File.exist?(file_path)
    
    File.readlines(file_path).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      
      if line.start_with?("#{env_key}=")
        value = line.split('=', 2)[1]
        return value.strip.gsub(/^["']|["']$/, '') # Remove quotes
      end
    end
    
    nil
  rescue => e
    Rails.logger.error "Failed to parse #{file_path} for #{env_key}: #{e.message}"
    nil
  end
  
  def suggest_default_model(provider)
    case provider.slug
    when 'openai'
      'gpt-4'
    when 'anthropic'
      'claude-3-haiku-20240307'
    when 'cohere'
      'command-r'
    when 'huggingface'
      'meta-llama/Llama-2-7b-chat-hf'
    when 'google'
      'gemini-1.5-flash'
    else
      provider.supported_models&.first || 'gpt-3.5-turbo'
    end
  end
end