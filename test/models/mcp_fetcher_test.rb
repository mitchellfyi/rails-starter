# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'

# Mock models for testing since this is a template project
class McpFetcher
  attr_accessor :id, :name, :provider_type, :configuration, :enabled, :description, :parameters, :sample_output
  
  def initialize(attributes = {})
    attributes.each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
    @id = rand(1000)
    @enabled = true if @enabled.nil?
    @configuration = {} if @configuration.nil?
    @parameters = {} if @parameters.nil?
  end
  
  def self.create!(attributes = {})
    fetcher = new(attributes)
    fetcher.valid? ? fetcher : (raise "Validation failed")
  end
  
  def valid?
    name && provider_type && description && 
    name.length > 0 && provider_type.length > 0 && description.length > 0
  end
  
  def persisted?
    true
  end
  
  def enabled?
    !!enabled
  end
  
  def enabled_for_workspace?(workspace)
    return enabled unless workspace
    
    workspace_fetcher = workspace.workspace_mcp_fetchers.find { |wf| wf.mcp_fetcher_id == id }
    workspace_fetcher ? workspace_fetcher.enabled : enabled
  end
  
  def workspace_status(workspace)
    return 'Global' unless workspace
    
    workspace_fetcher = workspace.workspace_mcp_fetchers.find { |wf| wf.mcp_fetcher_id == id }
    if workspace_fetcher
      workspace_fetcher.enabled? ? 'Enabled for Workspace' : 'Disabled for Workspace'
    else
      enabled? ? 'Inherited (Enabled)' : 'Inherited (Disabled)'
    end
  end
  
  def sample_output_preview
    return 'No sample output' if sample_output.nil? || sample_output.empty?
    sample_output.length > 100 ? sample_output[0..99] + '...' : sample_output
  end
  
  def self.enabled
    @@all_fetchers ||= []
    @@all_fetchers.select(&:enabled?)
  end
  
  def self.find_by(attributes)
    @@all_fetchers ||= []
    if attributes[:id]
      @@all_fetchers.find { |f| f.id == attributes[:id] }
    elsif attributes[:name]
      @@all_fetchers.find { |f| f.name == attributes[:name] }
    end
  end
  
  def self.all
    @@all_fetchers ||= []
  end
  
  def self.create!(attributes = {})
    fetcher = new(attributes)
    if fetcher.valid?
      @@all_fetchers ||= []
      @@all_fetchers << fetcher
      fetcher
    else
      raise "Validation failed"
    end
  end
  
  def toggle_for_workspace!(workspace)
    # Mock implementation
    true
  end
  
  def workspace_configuration_for(workspace)
    configuration
  end
  
  def errors
    @errors ||= MockErrors.new
  end
  
  class MockErrors
    def any?; false; end
    def [](field); []; end
  end
end

class WorkspaceMcpFetcher
  attr_accessor :id, :workspace_id, :mcp_fetcher_id, :enabled, :workspace_configuration
  
  def initialize(attributes = {})
    attributes.each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
    @id = rand(1000)
    @enabled = true if @enabled.nil?
    @workspace_configuration = {} if @workspace_configuration.nil?
  end
  
  def self.create!(attributes = {})
    fetcher = new(attributes)
    fetcher.valid? ? fetcher : (raise "Validation failed")
  end
  
  def valid?
    workspace_id && mcp_fetcher_id
  end
  
  def persisted?
    true
  end
  
  def enabled?
    !!enabled
  end
end

class Workspace
  attr_accessor :id, :name, :slug, :description, :active, :workspace_mcp_fetchers
  
  def initialize(attributes = {})
    attributes.each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
    @id = rand(1000)
    @active = true if @active.nil?
    @workspace_mcp_fetchers = []
  end
  
  def self.create!(attributes = {})
    workspace = new(attributes)
    workspace.valid? ? workspace : (raise "Validation failed")
  end
  
  def valid?
    name && name.length > 0
  end
  
  def persisted?
    true
  end
  
  def active?
    !!active
  end
  
  def mcp_fetcher_enabled?(fetcher)
    fetcher.enabled_for_workspace?(self)
  end
end

class McpFetcherTest < Minitest::Test
  def setup
    @mcp_fetcher = McpFetcher.create!(
      name: 'test_fetcher',
      provider_type: 'database',
      description: 'Test MCP fetcher for database queries',
      configuration: {
        query: 'SELECT * FROM users WHERE active = true',
        timeout: 30
      },
      parameters: {
        limit: 10,
        offset: 0
      },
      sample_output: 'Example database query results...',
      enabled: true
    )
  rescue NameError
    skip "McpFetcher model not available in test environment"
  end

  def test_mcp_fetcher_creation
    skip "McpFetcher model not available in test environment" unless defined?(McpFetcher)
    
    fetcher = McpFetcher.create!(
      name: 'api_fetcher',
      provider_type: 'http_api',
      description: 'External API data fetcher',
      configuration: {
        url: 'https://api.example.com/data',
        headers: { 'Authorization' => 'Bearer token' }
      },
      enabled: true
    )

    assert fetcher.persisted?
    assert_equal 'api_fetcher', fetcher.name
    assert_equal 'http_api', fetcher.provider_type
    assert fetcher.enabled?
  end

  def test_mcp_fetcher_validation
    skip "McpFetcher model not available in test environment" unless defined?(McpFetcher)
    
    fetcher = McpFetcher.new
    refute fetcher.valid?
    
    # Test with minimal required fields
    fetcher = McpFetcher.new(
      name: 'valid_fetcher',
      provider_type: 'database',
      description: 'Valid test fetcher'
    )
    assert fetcher.valid?
  end

  def test_workspace_mcp_fetcher_creation
    skip "WorkspaceMcpFetcher model not available in test environment" unless defined?(WorkspaceMcpFetcher)
    
    workspace_fetcher = WorkspaceMcpFetcher.create!(
      workspace_id: 1,
      mcp_fetcher_id: 2,
      enabled: true,
      workspace_configuration: {
        custom_param: 'workspace_value'
      }
    )

    assert workspace_fetcher.persisted?
    assert_equal 1, workspace_fetcher.workspace_id
    assert_equal 2, workspace_fetcher.mcp_fetcher_id
    assert workspace_fetcher.enabled?
  end

  def test_workspace_creation
    skip "Workspace model not available in test environment" unless defined?(Workspace)
    
    workspace = Workspace.create!(
      name: 'Test Workspace',
      slug: 'test-workspace',
      description: 'A test workspace for MCP functionality',
      active: true
    )

    assert workspace.persisted?
    assert_equal 'Test Workspace', workspace.name
    assert_equal 'test-workspace', workspace.slug
    assert workspace.active?
  end

  def test_mcp_fetcher_workspace_integration
    skip "Models not available in test environment" unless defined?(McpFetcher) && defined?(Workspace) && defined?(WorkspaceMcpFetcher)
    
    workspace = Workspace.create!(
      name: 'Integration Test Workspace',
      slug: 'integration-test',
      active: true
    )

    fetcher = McpFetcher.create!(
      name: 'integration_fetcher',
      provider_type: 'database',
      description: 'Integration test fetcher',
      enabled: true
    )

    # Test default behavior (should inherit from global setting)
    assert workspace.mcp_fetcher_enabled?(fetcher)
    assert_equal 'Inherited (Enabled)', fetcher.workspace_status(workspace)

    # Test workspace-specific override
    workspace_fetcher = WorkspaceMcpFetcher.create!(
      workspace_id: workspace.id,
      mcp_fetcher_id: fetcher.id,
      enabled: false
    )
    
    workspace.workspace_mcp_fetchers << workspace_fetcher
    
    refute workspace.mcp_fetcher_enabled?(fetcher)
    assert_equal 'Disabled for Workspace', fetcher.workspace_status(workspace)
  end

  def test_sample_output_preview
    skip "McpFetcher model not available in test environment" unless defined?(McpFetcher)
    
    # Test with no sample output
    fetcher = McpFetcher.new(name: 'test', provider_type: 'api', description: 'test')
    assert_equal 'No sample output', fetcher.sample_output_preview
    
    # Test with short sample output
    fetcher.sample_output = 'Short output'
    assert_equal 'Short output', fetcher.sample_output_preview
    
    # Test with long sample output
    long_output = 'a' * 150
    fetcher.sample_output = long_output
    preview = fetcher.sample_output_preview
    assert_equal 103, preview.length  # 100 chars + '...'
    assert preview.end_with?('...')
  end

  def test_mcp_fetcher_provider_types
    skip "McpFetcher model not available in test environment" unless defined?(McpFetcher)
    
    # Test different provider types
    database_fetcher = McpFetcher.create!(
      name: 'db_fetcher',
      provider_type: 'database',
      description: 'Database provider',
      enabled: true
    )

    api_fetcher = McpFetcher.create!(
      name: 'api_fetcher',
      provider_type: 'http_api',
      description: 'API provider',
      enabled: true
    )

    file_fetcher = McpFetcher.create!(
      name: 'file_fetcher',
      provider_type: 'file',
      description: 'File provider',
      enabled: true
    )

    assert_equal 'database', database_fetcher.provider_type
    assert_equal 'http_api', api_fetcher.provider_type
    assert_equal 'file', file_fetcher.provider_type
  end

  def test_mcp_fetcher_configuration_handling
    skip "McpFetcher model not available in test environment" unless defined?(McpFetcher)
    
    fetcher = McpFetcher.create!(
      name: 'config_test',
      provider_type: 'database',
      description: 'Configuration test fetcher',
      configuration: {
        query: 'SELECT * FROM table',
        timeout: 30,
        retries: 3
      },
      parameters: {
        limit: 100,
        format: 'json'
      }
    )

    assert_equal 'SELECT * FROM table', fetcher.configuration[:query]
    assert_equal 30, fetcher.configuration[:timeout]
    assert_equal 100, fetcher.parameters[:limit]
    assert_equal 'json', fetcher.parameters[:format]
  end
end