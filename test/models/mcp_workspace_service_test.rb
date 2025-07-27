# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'

# Load our test models
require_relative 'mcp_fetcher_test'

# Load the service class 
load File.expand_path('../../app/models/mcp_workspace_service.rb', __dir__)

class McpWorkspaceServiceTest < Minitest::Test
  def setup
    @workspace = Workspace.create!(
      name: 'Test Workspace',
      slug: 'test-workspace',
      description: 'Test workspace for MCP',
      active: true
    )
    
    @database_fetcher = McpFetcher.create!(
      name: 'user_database',
      provider_type: 'database',
      description: 'Fetch user data from database',
      configuration: {
        query: 'SELECT * FROM users WHERE active = true',
        timeout: 30
      },
      enabled: true
    )
    
    @api_fetcher = McpFetcher.create!(
      name: 'external_api',
      provider_type: 'http_api',
      description: 'Fetch data from external API',
      configuration: {
        url: 'https://api.example.com/data',
        headers: { 'Authorization' => 'Bearer token' }
      },
      enabled: true
    )
    
    @disabled_fetcher = McpFetcher.create!(
      name: 'disabled_fetcher',
      provider_type: 'database',
      description: 'Disabled fetcher',
      configuration: { query: 'SELECT 1' },
      enabled: false
    )
  end
  
  def test_service_initialization
    service = McpWorkspaceService.new
    assert_nil service.workspace
    assert_empty service.to_h
    
    workspace_service = McpWorkspaceService.new(@workspace)
    assert_equal @workspace, workspace_service.workspace
    assert_empty workspace_service.to_h
  end
  
  def test_fetch_with_database_provider
    service = McpWorkspaceService.new(@workspace)
    
    result = service.fetch(:users, {
      fetcher_name: 'user_database',
      params: { limit: 5 }
    })
    
    assert result
    assert_equal 'database', result[:type]
    assert result[:results].is_a?(Array)
    assert_equal 5, result[:results].length
    assert result[:timestamp]
    
    # Check that data is stored in service
    assert_equal result, service.to_h[:users]
  end
  
  def test_fetch_with_api_provider
    service = McpWorkspaceService.new(@workspace)
    
    result = service.fetch(:api_data, {
      fetcher_name: 'external_api',
      params: { query: 'test search' }
    })
    
    assert result
    assert_equal 'api', result[:type]
    assert_equal 200, result[:status]
    assert result[:data]
    assert result[:timestamp]
  end
  
  def test_fetch_with_disabled_fetcher
    service = McpWorkspaceService.new(@workspace)
    
    result = service.fetch(:disabled_data, {
      fetcher_name: 'disabled_fetcher'
    })
    
    assert result[:error]
    assert_match(/disabled for workspace/i, result[:message])
  end
  
  def test_fetch_with_nonexistent_fetcher
    service = McpWorkspaceService.new(@workspace)
    
    result = service.fetch(:missing_data, {
      fetcher_name: 'nonexistent_fetcher'
    })
    
    assert result[:error]
    assert_match(/fetcher not found/i, result[:message])
  end
  
  def test_enabled_fetchers_without_workspace
    service = McpWorkspaceService.new
    
    # Mock the McpFetcher.enabled scope
    def McpFetcher.enabled
      [@database_fetcher, @api_fetcher]
    end
    
    enabled = service.enabled_fetchers
    assert enabled.is_a?(Array)
  end
  
  def test_enabled_fetchers_with_workspace
    service = McpWorkspaceService.new(@workspace)
    
    # Mock workspace enabled_mcp_fetchers method
    def @workspace.enabled_mcp_fetchers
      [@database_fetcher] # Only database fetcher enabled for this workspace
    end
    
    enabled = service.enabled_fetchers
    assert enabled.is_a?(Array)
  end
  
  def test_available_fetchers
    service = McpWorkspaceService.new(@workspace)
    
    # Mock McpFetcher.all
    def McpFetcher.all
      [@database_fetcher, @api_fetcher, @disabled_fetcher]
    end
    
    available = service.available_fetchers
    assert available.is_a?(Array)
  end
  
  def test_fetcher_status
    service = McpWorkspaceService.new(@workspace)
    
    status = service.fetcher_status(@database_fetcher)
    assert status.is_a?(String)
    
    # Test without workspace
    global_service = McpWorkspaceService.new
    global_status = global_service.fetcher_status(@database_fetcher)
    assert_equal 'Global', global_status
  end
  
  def test_toggle_fetcher
    service = McpWorkspaceService.new(@workspace)
    
    # Test toggle with workspace
    result = service.toggle_fetcher!(@database_fetcher)
    assert result
    
    # Test toggle without workspace
    global_service = McpWorkspaceService.new
    result = global_service.toggle_fetcher!(@database_fetcher)
    refute result
    
    # Test toggle with nil fetcher
    result = service.toggle_fetcher!(nil)
    refute result
  end
  
  def test_multiple_fetches
    service = McpWorkspaceService.new(@workspace)
    
    # Fetch from multiple sources
    service.fetch(:users, { fetcher_name: 'user_database' })
    service.fetch(:api_data, { fetcher_name: 'external_api' })
    
    context = service.to_h
    assert context[:users]
    assert context[:api_data]
    assert_equal 2, context.keys.length
  end
  
  def test_to_json
    service = McpWorkspaceService.new(@workspace)
    
    service.fetch(:test_data, { fetcher_name: 'user_database' })
    
    json_string = service.to_json
    assert json_string.is_a?(String)
    
    # Parse back to verify it's valid JSON
    require 'json'
    parsed = JSON.parse(json_string)
    assert parsed['test_data'] || parsed[:test_data]
  end
  
  def test_clear
    service = McpWorkspaceService.new(@workspace)
    
    service.fetch(:test_data, { fetcher_name: 'user_database' })
    refute_empty service.to_h
    refute_empty service.audit_entries
    
    service.clear!
    assert_empty service.to_h
    assert_empty service.audit_entries
  end
  
  def test_audit_logging
    service = McpWorkspaceService.new(@workspace)
    
    service.fetch(:test_data, { fetcher_name: 'user_database' })
    
    audit_entries = service.audit_entries
    refute_empty audit_entries
    
    entry = audit_entries.first
    assert_equal @workspace.id, entry[:workspace_id]
    assert_equal @database_fetcher.id, entry[:fetcher_id]
    assert_equal 'user_database', entry[:fetcher_name]
    assert_equal 'test_data', entry[:context_key]
    assert_equal 'success', entry[:status]
    assert entry[:timestamp]
  end
  
  def test_error_handling_and_audit
    service = McpWorkspaceService.new(@workspace)
    
    # Force an error by using invalid configuration
    original_method = service.method(:fetch_context_data)
    service.define_singleton_method(:fetch_context_data) do |fetcher, config|
      raise StandardError.new("Simulated error")
    end
    
    result = service.fetch(:error_data, { fetcher_name: 'user_database' })
    
    assert result[:error]
    assert_match(/simulated error/i, result[:message])
    
    # Check that error is audited
    error_entry = service.audit_entries.find { |e| e[:status] == 'error' }
    assert error_entry
    assert_match(/simulated error/i, error_entry[:error_message])
  end
  
  def test_workspace_specific_configuration
    service = McpWorkspaceService.new(@workspace)
    
    # Mock workspace-specific configuration
    def @database_fetcher.workspace_configuration_for(workspace)
      {
        query: 'SELECT * FROM users WHERE workspace_id = ?',
        workspace_id: workspace.id,
        timeout: 60
      }
    end
    
    result = service.fetch(:workspace_users, { fetcher_name: 'user_database' })
    
    assert result
    assert_equal 'database', result[:type]
    assert result[:results]
  end

  private
  
  def instance_variable_get(name)
    case name
    when :@database_fetcher
      @database_fetcher
    when :@api_fetcher  
      @api_fetcher
    when :@disabled_fetcher
      @disabled_fetcher
    else
      super
    end
  end
end