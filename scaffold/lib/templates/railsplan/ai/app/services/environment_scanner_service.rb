# frozen_string_literal: true

# Service for scanning environment variables and suggesting credential mappings
class EnvironmentScannerService
  # Common environment variable patterns for AI providers
  ENV_PATTERNS = {
    'openai' => [
      'OPENAI_API_KEY',
      'OPENAI_KEY', 
      'OPENAI_SECRET_KEY',
      'OPENAI_ACCESS_TOKEN'
    ],
    'anthropic' => [
      'ANTHROPIC_API_KEY',
      'CLAUDE_API_KEY',
      'ANTHROPIC_KEY'
    ],
    'cohere' => [
      'COHERE_API_KEY',
      'COHERE_KEY'
    ],
    'huggingface' => [
      'HUGGINGFACE_API_KEY',
      'HF_API_KEY',
      'HUGGINGFACE_TOKEN'
    ],
    'google' => [
      'GOOGLE_AI_API_KEY',
      'GOOGLE_API_KEY',
      'GEMINI_API_KEY'
    ],
    'azure' => [
      'AZURE_OPENAI_API_KEY',
      'AZURE_OPENAI_KEY',
      'AZURE_API_KEY'
    ]
  }.freeze
  
  def scan_environment_variables
    detected_vars = {}
    
    # Scan actual environment variables
    ENV_PATTERNS.each do |provider, patterns|
      patterns.each do |pattern|
        if ENV[pattern].present?
          detected_vars[pattern] = {
            value: mask_secret(ENV[pattern]),
            provider: provider,
            source: 'environment'
          }
        end
      end
    end
    
    # Scan .env files
    detected_vars.merge!(scan_env_files)
    
    detected_vars
  end
  
  def scan_env_files
    detected_vars = {}
    env_files = ['.env', '.env.local', '.env.development', '.env.production']
    
    env_files.each do |file_path|
      next unless File.exist?(file_path)
      
      File.readlines(file_path).each_with_index do |line, index|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        
        if line.include?('=')
          key, value = line.split('=', 2)
          key = key.strip
          value = value.strip.gsub(/^["']|["']$/, '') # Remove quotes
          
          ENV_PATTERNS.each do |provider, patterns|
            if patterns.include?(key) && value.present? && !value.include?('your_') && !value.include?('example')
              detected_vars[key] = {
                value: mask_secret(value),
                provider: provider,
                source: "#{file_path}:#{index + 1}"
              }
            end
          end
        end
      end
    rescue => e
      Rails.logger.warn "Failed to scan #{file_path}: #{e.message}"
    end
    
    detected_vars
  end
  
  def suggest_credential_mappings(detected_vars)
    suggestions = []
    
    detected_vars.group_by { |_, data| data[:provider] }.each do |provider_slug, vars|
      provider = AiProvider.find_by(slug: provider_slug)
      next unless provider
      
      vars.each do |env_key, data|
        suggestions << {
          env_key: env_key,
          env_source: data[:source],
          provider: provider,
          suggested_name: generate_credential_name(provider, env_key),
          suggested_model: suggest_default_model(provider),
          api_key_source: env_key
        }
      end
    end
    
    suggestions
  end
  
  def validate_api_key_format(provider_slug, api_key)
    case provider_slug
    when 'openai'
      api_key.match?(/^sk-[a-zA-Z0-9]{48,}$/)
    when 'anthropic'
      api_key.match?(/^sk-ant-[a-zA-Z0-9-_]{10,}$/)
    when 'cohere'
      api_key.match?(/^[a-zA-Z0-9-_]{40,}$/)
    when 'huggingface'
      api_key.match?(/^hf_[a-zA-Z0-9]{34}$/)
    else
      api_key.length > 10 # Basic length check for unknown providers
    end
  end
  
  private
  
  def mask_secret(value)
    return '' if value.blank?
    
    if value.length <= 8
      '*' * value.length
    else
      "#{value[0..3]}#{'*' * (value.length - 8)}#{value[-4..-1]}"
    end
  end
  
  def generate_credential_name(provider, env_key)
    # Generate a descriptive name based on provider and environment key
    base_name = provider.name
    
    if env_key.include?('PRODUCTION') || env_key.include?('PROD')
      "#{base_name} (Production)"
    elsif env_key.include?('DEVELOPMENT') || env_key.include?('DEV')
      "#{base_name} (Development)"
    elsif env_key.include?('TEST')
      "#{base_name} (Test)"
    else
      "#{base_name} (Imported)"
    end
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
      provider.supported_models&.first
    end
  end
end