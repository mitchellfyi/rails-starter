# frozen_string_literal: true

# Service for integrating with 1Password CLI
class OnePasswordIntegrationService
  attr_reader :config
  
  def initialize
    @config = {
      vault: ENV['ONEPASSWORD_VAULT'] || 'AI Credentials',
      service_account_token: ENV['OP_SERVICE_ACCOUNT_TOKEN'],
      connect_host: ENV['OP_CONNECT_HOST'],
      connect_token: ENV['OP_CONNECT_TOKEN'
    }
  end
  
  def available?
    (cli_available? && service_account_configured?) || connect_configured?
  end
  
  def connection_status
    if connect_configured?
      test_connect_integration
    elsif cli_available? && service_account_configured?
      test_cli_integration
    else
      {
        connected: false,
        error: 'Neither 1Password CLI with service account nor Connect integration is configured'
      }
    end
  end
  
  def sync_secrets_to_workspace(workspace)
    return { success: false, error: '1Password not available' } unless available?
    
    begin
      secrets = fetch_secrets_from_onepassword
      imported_count = 0
      errors = []
      
      secrets.each do |item|
        begin
          credential = create_credential_from_onepassword_item(workspace, item)
          imported_count += 1 if credential
        rescue => e
          errors << "Failed to import #{item['title']}: #{e.message}"
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
  
  def store_credential_in_onepassword(ai_credential)
    return { success: false, error: '1Password not available' } unless available?
    
    begin
      item_data = {
        title: "#{ai_credential.ai_provider.name} - #{ai_credential.name}",
        category: 'API_CREDENTIAL',
        vault: config[:vault],
        fields: [
          {
            label: 'API Key',
            type: 'concealed',
            value: ai_credential.api_key
          },
          {
            label: 'Provider',
            type: 'text',
            value: ai_credential.ai_provider.slug
          },
          {
            label: 'Model',
            type: 'text',
            value: ai_credential.preferred_model
          },
          {
            label: 'Workspace ID',
            type: 'text',
            value: ai_credential.workspace_id.to_s
          }
        ],
        tags: ['ai-credential', ai_credential.ai_provider.slug, ai_credential.workspace.slug]
      }
      
      if connect_configured?
        result = create_item_via_connect(item_data)
      else
        result = create_item_via_cli(item_data)
      end
      
      {
        success: true,
        item_id: result['id'],
        item_title: result['title']
      }
      
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
  
  def fetch_credential_from_onepassword(item_id)
    return { success: false, error: '1Password not available' } unless available?
    
    begin
      if connect_configured?
        item = get_item_via_connect(item_id)
      else
        item = get_item_via_cli(item_id)
      end
      
      {
        success: true,
        data: item
      }
      
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
  
  private
  
  def cli_available?
    system('which op > /dev/null 2>&1')
  end
  
  def service_account_configured?
    config[:service_account_token].present?
  end
  
  def connect_configured?
    config[:connect_host].present? && config[:connect_token].present?
  end
  
  def test_cli_integration
    begin
      result = execute_op_command(['account', 'list', '--format', 'json'])
      accounts = JSON.parse(result)
      
      {
        connected: true,
        method: 'CLI with Service Account',
        accounts_count: accounts.length,
        message: 'Connected to 1Password CLI'
      }
    rescue => e
      {
        connected: false,
        error: e.message
      }
    end
  end
  
  def test_connect_integration
    begin
      response = make_connect_request('GET', 'health')
      
      {
        connected: true,
        method: '1Password Connect',
        version: response['version'],
        message: 'Connected to 1Password Connect'
      }
    rescue => e
      {
        connected: false,
        error: e.message
      }
    end
  end
  
  def fetch_secrets_from_onepassword
    if connect_configured?
      fetch_items_via_connect
    else
      fetch_items_via_cli
    end
  end
  
  def fetch_items_via_cli
    result = execute_op_command([
      'item', 'list',
      '--vault', config[:vault],
      '--categories', 'API_Credential,Secure_Note,Login',
      '--format', 'json'
    ])
    
    items = JSON.parse(result)
    
    # Filter for AI-related items
    items.select { |item| ai_related_item?(item) }
  end
  
  def fetch_items_via_connect
    vault_id = get_vault_id_by_name(config[:vault])
    response = make_connect_request('GET', "vaults/#{vault_id}/items")
    
    items = response
    
    # Filter for AI-related items and get full details
    ai_items = items.select { |item| ai_related_item?(item) }
    
    ai_items.map do |item|
      make_connect_request('GET', "vaults/#{vault_id}/items/#{item['id']}")
    end
  end
  
  def ai_related_item?(item)
    title = item['title'].downcase
    tags = item['tags'] || []
    
    ai_keywords = ['openai', 'anthropic', 'claude', 'cohere', 'huggingface', 'gemini', 'api key', 'ai-credential']
    
    ai_keywords.any? { |keyword| title.include?(keyword) } ||
      tags.any? { |tag| ai_keywords.any? { |keyword| tag.downcase.include?(keyword) } }
  end
  
  def create_credential_from_onepassword_item(workspace, item)
    # Extract API key from item
    api_key = extract_api_key_from_item(item)
    return nil unless api_key.present?
    
    # Detect provider from title and fields
    provider = detect_provider_from_item(item)
    return nil unless provider
    
    # Check if credential already exists
    existing = workspace.ai_credentials.find_by(
      ai_provider: provider,
      onepassword_item_id: item['id']
    )
    
    if existing
      # Update existing credential
      existing.update!(
        api_key: api_key,
        onepassword_synced_at: Time.current
      )
      return existing
    else
      # Create new credential
      credential_name = "#{provider.name} (1Password: #{item['title']})"
      
      return workspace.ai_credentials.create!(
        ai_provider: provider,
        name: credential_name,
        api_key: api_key,
        preferred_model: suggest_default_model(provider),
        temperature: 0.7,
        max_tokens: 4096,
        response_format: 'text',
        active: true,
        onepassword_item_id: item['id'],
        onepassword_synced_at: Time.current
      )
    end
  end
  
  def extract_api_key_from_item(item)
    fields = item['fields'] || []
    
    # Look for fields that likely contain API keys
    api_key_fields = fields.select do |field|
      label = field['label'].downcase
      label.include?('api key') || label.include?('token') || label.include?('secret')
    end
    
    # Return the first API key found
    api_key_fields.first&.dig('value')
  end
  
  def detect_provider_from_item(item)
    title = item['title'].downcase
    
    case title
    when /openai/
      AiProvider.find_by(slug: 'openai')
    when /anthropic|claude/
      AiProvider.find_by(slug: 'anthropic')
    when /cohere/
      AiProvider.find_by(slug: 'cohere')
    when /huggingface|hugging\s*face/
      AiProvider.find_by(slug: 'huggingface')
    when /google|gemini/
      AiProvider.find_by(slug: 'google')
    when /azure/
      AiProvider.find_by(slug: 'azure')
    else
      # Try to detect from fields
      fields = item['fields'] || []
      provider_field = fields.find { |f| f['label'].downcase.include?('provider') }
      if provider_field
        AiProvider.find_by(slug: provider_field['value'])
      else
        nil
      end
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
      provider.supported_models&.first || 'gpt-3.5-turbo'
    end
  end
  
  def execute_op_command(args)
    env = {}
    env['OP_SERVICE_ACCOUNT_TOKEN'] = config[:service_account_token] if config[:service_account_token]
    
    cmd = ['op'] + args
    result = `#{env.map { |k, v| "#{k}=#{v}" }.join(' ')} #{cmd.join(' ')} 2>&1`
    
    unless $?.success?
      raise "1Password CLI command failed: #{result}"
    end
    
    result
  end
  
  def make_connect_request(method, path, body = nil)
    require 'net/http'
    require 'json'
    
    uri = URI("#{config[:connect_host]}/v1/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = case method.upcase
             when 'GET'
               Net::HTTP::Get.new(uri)
             when 'POST'
               Net::HTTP::Post.new(uri)
             else
               raise "Unsupported HTTP method: #{method}"
             end
    
    request['Authorization'] = "Bearer #{config[:connect_token]}"
    request['Content-Type'] = 'application/json'
    
    if body
      request.body = body.to_json
    end
    
    response = http.request(request)
    
    unless response.code.start_with?('2')
      raise "1Password Connect request failed: #{response.code} - #{response.body}"
    end
    
    JSON.parse(response.body) if response.body.present?
  end
  
  def get_vault_id_by_name(vault_name)
    vaults = make_connect_request('GET', 'vaults')
    vault = vaults.find { |v| v['name'] == vault_name }
    
    raise "Vault '#{vault_name}' not found" unless vault
    
    vault['id']
  end
  
  def create_item_via_cli(item_data)
    # Convert item data to CLI format
    template = {
      title: item_data[:title],
      category: item_data[:category],
      vault: item_data[:vault],
      fields: item_data[:fields],
      tags: item_data[:tags]
    }
    
    # Create temporary file with item template
    require 'tempfile'
    
    Tempfile.create(['op_item', '.json']) do |file|
      file.write(template.to_json)
      file.flush
      
      result = execute_op_command(['item', 'create', '--template', file.path, '--format', 'json'])
      JSON.parse(result)
    end
  end
  
  def create_item_via_connect(item_data)
    vault_id = get_vault_id_by_name(item_data[:vault])
    
    make_connect_request('POST', "vaults/#{vault_id}/items", item_data)
  end
  
  def get_item_via_cli(item_id)
    result = execute_op_command(['item', 'get', item_id, '--format', 'json'])
    JSON.parse(result)
  end
  
  def get_item_via_connect(item_id)
    # First get vaults to find the item
    vaults = make_connect_request('GET', 'vaults')
    
    vaults.each do |vault|
      begin
        return make_connect_request('GET', "vaults/#{vault['id']}/items/#{item_id}")
      rescue
        # Item not in this vault, continue
      end
    end
    
    raise "Item #{item_id} not found"
  end
end