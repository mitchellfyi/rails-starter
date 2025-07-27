# frozen_string_literal: true

# Service for integrating with Doppler
class DopplerIntegrationService
  attr_reader :config
  
  def initialize
    @config = {
      token: ENV['DOPPLER_TOKEN'],
      project: ENV['DOPPLER_PROJECT'] || 'ai-credentials',
      config_name: ENV['DOPPLER_CONFIG'] || 'prd'
    }
  end
  
  def available?
    config[:token].present? && doppler_cli_available?
  end
  
  def connection_status
    return { connected: false, error: 'DOPPLER_TOKEN not configured' } unless config[:token].present?
    return { connected: false, error: 'Doppler CLI not available' } unless doppler_cli_available?
    
    begin
      result = execute_doppler_command(['me'])
      {
        connected: true,
        user: result.dig('user', 'email'),
        workplace: result.dig('workplace', 'name'),
        message: 'Connected to Doppler'
      }
    rescue => e
      {
        connected: false,
        error: e.message
      }
    end
  end
  
  def sync_secrets_to_workspace(workspace)
    return { success: false, error: 'Doppler not available' } unless available?
    
    begin
      secrets = fetch_secrets_from_doppler
      imported_count = 0
      errors = []
      
      secrets.each do |secret_name, secret_value|
        next unless ai_related_secret?(secret_name)
        
        begin
          credential = create_credential_from_doppler_secret(workspace, secret_name, secret_value)
          imported_count += 1 if credential
        rescue => e
          errors << "Failed to import #{secret_name}: #{e.message}"
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
  
  def store_secret_in_doppler(name, value)
    return { success: false, error: 'Doppler not available' } unless available?
    
    begin
      execute_doppler_command([
        'secrets', 'set',
        name,
        value,
        '--project', config[:project],
        '--config', config[:config_name]
      ])
      
      {
        success: true,
        message: "Secret #{name} stored in Doppler"
      }
      
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
  
  def fetch_secret_from_doppler(name)
    return { success: false, error: 'Doppler not available' } unless available?
    
    begin
      result = execute_doppler_command([
        'secrets', 'get', name,
        '--project', config[:project],
        '--config', config[:config_name],
        '--plain'
      ])
      
      {
        success: true,
        value: result.strip
      }
      
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
  
  private
  
  def doppler_cli_available?
    system('which doppler > /dev/null 2>&1')
  end
  
  def fetch_secrets_from_doppler
    result = execute_doppler_command([
      'secrets', 'download',
      '--project', config[:project],
      '--config', config[:config_name],
      '--format', 'json'
    ])
    
    JSON.parse(result)
  end
  
  def ai_related_secret?(secret_name)
    ai_patterns = [
      'OPENAI', 'ANTHROPIC', 'CLAUDE', 'COHERE', 'HUGGINGFACE', 'HF_',
      'GOOGLE_AI', 'GEMINI', 'AZURE_OPENAI', 'API_KEY'
    ]
    
    ai_patterns.any? { |pattern| secret_name.upcase.include?(pattern) }
  end
  
  def create_credential_from_doppler_secret(workspace, secret_name, secret_value)
    provider = detect_provider_from_secret_name(secret_name)
    return nil unless provider
    return nil if secret_value.blank? || placeholder_value?(secret_value)
    
    # Check if credential already exists
    existing = workspace.ai_credentials.find_by(
      ai_provider: provider,
      doppler_secret_name: secret_name
    )
    
    if existing
      # Update existing credential
      existing.update!(
        api_key: secret_value,
        doppler_synced_at: Time.current
      )
      return existing
    else
      # Create new credential
      credential_name = "#{provider.name} (Doppler: #{secret_name})"
      
      return workspace.ai_credentials.create!(
        ai_provider: provider,
        name: credential_name,
        api_key: secret_value,
        preferred_model: suggest_default_model(provider),
        temperature: 0.7,
        max_tokens: 4096,
        response_format: 'text',
        active: true,
        doppler_secret_name: secret_name,
        doppler_synced_at: Time.current
      )
    end
  end
  
  def detect_provider_from_secret_name(secret_name)
    name_upper = secret_name.upcase
    
    case name_upper
    when /OPENAI/
      AiProvider.find_by(slug: 'openai')
    when /ANTHROPIC|CLAUDE/
      AiProvider.find_by(slug: 'anthropic')
    when /COHERE/
      AiProvider.find_by(slug: 'cohere')
    when /HUGGINGFACE|HF_/
      AiProvider.find_by(slug: 'huggingface')
    when /GOOGLE_AI|GEMINI/
      AiProvider.find_by(slug: 'google')
    when /AZURE_OPENAI/
      AiProvider.find_by(slug: 'azure')
    else
      nil
    end
  end
  
  def placeholder_value?(value)
    placeholder_patterns = [
      'your_', 'example', 'replace_', 'change_me', 'todo', 'fixme',
      'sk-...', 'key_here', 'api_key_here'
    ]
    
    value_lower = value.downcase
    placeholder_patterns.any? { |pattern| value_lower.include?(pattern) }
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
  
  def execute_doppler_command(args)
    cmd = ['doppler'] + args
    cmd += ['--token', config[:token]] if config[:token]
    
    result = `#{cmd.join(' ')} 2>&1`
    
    unless $?.success?
      raise "Doppler command failed: #{result}"
    end
    
    result
  end
end