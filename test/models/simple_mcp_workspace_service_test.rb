# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'
require 'time'
require 'json'

# Load the service class 
load File.expand_path('../../app/models/mcp_workspace_service.rb', __dir__)

# Mock models for testing
class MockMcpFetcher
  attr_accessor :id, :name, :provider_type, :configuration, :enabled, :description
  
  @@all_fetchers = []
  
  def initialize(attributes = {})
    attributes.each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
    @id = rand(1000)
    @enabled = true if @enabled.nil?
    @configuration = {} if @configuration.nil?
  end
  
  def self.create!(attributes = {})
    fetcher = new(attributes)
    @@all_fetchers << fetcher
    fetcher
  end
  
  def self.find_by(attributes)
    if attributes[:id]
      @@all_fetchers.find { |f| f.id == attributes[:id] }
    elsif attributes[:name]
      @@all_fetchers.find { |f| f.name == attributes[:name] }
    end
  end
  
  def self.enabled
    @@all_fetchers.select(&:enabled?)
  end
  
  def self.all
    @@all_fetchers
  end
  
  def self.clear_all!
    @@all_fetchers.clear
  end
  
  def enabled?
    !!enabled
  end
  
  def enabled_for_workspace?(workspace)
    enabled
  end
  
  def workspace_status(workspace)
    enabled? ? 'Inherited (Enabled)' : 'Inherited (Disabled)'
  end
  
  def toggle_for_workspace!(workspace)
    true
  end
  
  def workspace_configuration_for(workspace)
    configuration
  end
end

class MockWorkspace
  attr_accessor :id, :name, :slug
  
  def initialize(attributes = {})
    attributes.each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
    @id = rand(1000)
  end
  
  def enabled_mcp_fetchers
    MockMcpFetcher.enabled
  end
end

# Replace the constants in the service
class McpWorkspaceService
  private
  
  # Override the find_fetcher_by_config to use mock
  def find_fetcher_by_config(config)
    if config[:fetcher_id]
      MockMcpFetcher.find_by(id: config[:fetcher_id])
    elsif config[:fetcher_name]
      MockMcpFetcher.find_by(name: config[:fetcher_name])
    elsif config[:name]
      MockMcpFetcher.find_by(name: config[:name])
    else
      MockMcpFetcher.enabled.find { |f| f.provider_type == (config[:type] || config[:provider_type]) }
    end
  end
  
  # Override enabled_fetchers to use mock
  def enabled_fetchers
    return MockMcpFetcher.enabled.to_a unless workspace
    workspace.enabled_mcp_fetchers.to_a
  end
  
  def available_fetchers
    MockMcpFetcher.all.to_a
  end
end

class SimpleMcpWorkspaceServiceTest < Minitest::Test
  def setup
    MockMcpFetcher.clear_all!
    
    @workspace = MockWorkspace.new(
      name: 'Test Workspace',
      slug: 'test-workspace'
    )
    
    @database_fetcher = MockMcpFetcher.create!(
      name: 'user_database',
      provider_type: 'database',
      description: 'Fetch user data from database',
      configuration: {
        query: 'SELECT * FROM users WHERE active = true',
        timeout: 30
      },
      enabled: true
    )
    
    @api_fetcher = MockMcpFetcher.create!(
      name: 'external_api',
      provider_type: 'http_api',
      description: 'Fetch data from external API',
      configuration: {
        url: 'https://api.example.com/data',
        headers: { 'Authorization' => 'Bearer token' }
      },
      enabled: true
    )
    
    @disabled_fetcher = MockMcpFetcher.create!(
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
  
  def test_enabled_fetchers
    service = McpWorkspaceService.new(@workspace)
    
    enabled = service.enabled_fetchers
    assert enabled.is_a?(Array)
    assert enabled.any? { |f| f.name == 'user_database' }
    assert enabled.any? { |f| f.name == 'external_api' }
    refute enabled.any? { |f| f.name == 'disabled_fetcher' }
  end
  
  def test_available_fetchers
    service = McpWorkspaceService.new(@workspace)
    
    available = service.available_fetchers
    assert available.is_a?(Array)
    assert_equal 3, available.length
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
end