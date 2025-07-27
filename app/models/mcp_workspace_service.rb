# frozen_string_literal: true

class McpWorkspaceService
  attr_reader :workspace, :context_data, :audit_entries
  
  def initialize(workspace = nil)
    @workspace = workspace
    @context_data = {}
    @audit_entries = []
  end
  
  def fetch(key, config = {})
    fetcher = find_fetcher_by_config(config)
    
    return log_error(key, "Fetcher not found for key: #{key}") unless fetcher
    return log_error(key, "Fetcher disabled for workspace") unless fetcher_enabled?(fetcher)
    
    begin
      start_time = Time.now
      data = fetch_context_data(fetcher, config)
      duration = Time.now - start_time
      
      @context_data[key] = data
      log_audit(fetcher, key, data, duration, 'success')
      
      data
    rescue => error
      log_audit(fetcher, key, nil, nil, 'error', error.message)
      log_error(key, error.message)
    end
  end
  
  def enabled_fetchers
    return McpFetcher.enabled.to_a unless workspace
    
    workspace.enabled_mcp_fetchers.to_a
  end
  
  def available_fetchers
    McpFetcher.all.to_a
  end
  
  def fetcher_status(fetcher)
    return 'Global' unless workspace
    fetcher.workspace_status(workspace)
  end
  
  def toggle_fetcher!(fetcher)
    return false unless workspace && fetcher
    
    fetcher.toggle_for_workspace!(workspace)
    log_audit(fetcher, 'toggle', nil, nil, 'toggle', "Toggled to #{fetcher.enabled_for_workspace?(workspace)}")
    true
  end
  
  def to_h
    @context_data.dup
  end
  
  def to_json
    @context_data.to_json
  end
  
  def clear!
    @context_data.clear
    @audit_entries.clear
  end
  
  private
  
  def find_fetcher_by_config(config)
    if config[:fetcher_id]
      McpFetcher.find_by(id: config[:fetcher_id])
    elsif config[:fetcher_name]
      McpFetcher.find_by(name: config[:fetcher_name])
    elsif config[:name]
      McpFetcher.find_by(name: config[:name])
    else
      # Try to find by provider type as fallback
      McpFetcher.enabled.find_by(provider_type: config[:type] || config[:provider_type])
    end
  end
  
  def fetcher_enabled?(fetcher)
    return false unless fetcher
    
    if workspace
      fetcher.enabled_for_workspace?(workspace)
    else
      fetcher.enabled?
    end
  end
  
  def fetch_context_data(fetcher, config)
    # Get workspace-specific configuration
    effective_config = workspace ? fetcher.workspace_configuration_for(workspace) : fetcher.configuration
    merged_config = effective_config.merge(config[:params] || {})
    
    # Create provider based on fetcher type and execute
    case fetcher.provider_type
    when 'database'
      fetch_database_data(merged_config)
    when 'http_api', 'api'
      fetch_api_data(merged_config)
    when 'file'
      fetch_file_data(merged_config)
    else
      raise "Unknown provider type: #{fetcher.provider_type}"
    end
  end
  
  def fetch_database_data(config)
    # Simulate database fetch - in real implementation this would use ActiveRecord
    {
      type: 'database',
      query: config[:query] || 'SELECT * FROM table',
      results: simulate_database_results(config),
      timestamp: Time.now.iso8601
    }
  end
  
  def fetch_api_data(config)
    # Simulate API fetch - in real implementation this would make HTTP requests
    {
      type: 'api',
      url: config[:url] || 'https://api.example.com',
      status: 200,
      data: simulate_api_results(config),
      timestamp: Time.now.iso8601
    }
  end
  
  def fetch_file_data(config)
    # Simulate file fetch - in real implementation this would read files
    {
      type: 'file',
      path: config[:path] || '/tmp/data.json',
      content: simulate_file_results(config),
      timestamp: Time.now.iso8601
    }
  end
  
  def simulate_database_results(config)
    limit = config[:limit] || 10
    Array.new(limit) do |i|
      {
        id: i + 1,
        name: "Record #{i + 1}",
        created_at: (Time.now - i.days).iso8601
      }
    end
  end
  
  def simulate_api_results(config)
    {
      message: "API response from #{config[:url]}",
      data: { query: config[:query], limit: config[:limit] },
      success: true
    }
  end
  
  def simulate_file_results(config)
    {
      filename: File.basename(config[:path] || 'data.json'),
      format: config[:format] || 'json',
      lines: config[:lines] || 100
    }
  end
  
  def log_audit(fetcher, key, data, duration, status, error_message = nil)
    entry = {
      workspace_id: workspace&.id,
      fetcher_id: fetcher&.id,
      fetcher_name: fetcher&.name,
      context_key: key.to_s,
      status: status,
      duration_ms: duration ? (duration * 1000).round(2) : nil,
      error_message: error_message,
      data_preview: data ? data.to_s.truncate(100) : nil,
      timestamp: Time.now.iso8601
    }
    
    @audit_entries << entry
    
    # In a real Rails app, this would create an AuditLog record
    if defined?(AuditLog) && workspace.respond_to?(:users)
      AuditLog.create_log(
        user: nil, # Would be current_user in real implementation
        action: 'mcp_context_fetch',
        resource_type: 'McpFetcher',
        resource_id: fetcher&.id,
        description: "Fetched context '#{key}' using #{fetcher&.name} (#{status})",
        metadata: entry
      )
    end
  end
  
  def log_error(key, message)
    error_data = {
      error: true,
      message: message,
      key: key.to_s,
      timestamp: Time.now.iso8601
    }
    
    @context_data[key] = error_data
    error_data
  end
end