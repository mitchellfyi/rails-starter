# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'

# Full integration test demonstrating the MCP per workspace workflow
class McpWorkspaceIntegrationTest < Minitest::Test
  def setup
    # Mock the necessary models
    load_mcp_models
    
    # Create test data
    @workspace1 = create_workspace('Engineering Team', 'engineering')
    @workspace2 = create_workspace('Marketing Team', 'marketing')
    
    @database_fetcher = create_mcp_fetcher(
      name: 'user_database',
      provider_type: 'database',
      description: 'Fetch user analytics from database',
      configuration: {
        query: 'SELECT COUNT(*) as user_count, AVG(login_frequency) as avg_logins FROM users WHERE workspace_id = ?',
        timeout: 30
      },
      enabled: true
    )
    
    @api_fetcher = create_mcp_fetcher(
      name: 'slack_integration',
      provider_type: 'http_api',
      description: 'Fetch team communication metrics from Slack',
      configuration: {
        url: 'https://slack.com/api/team.info',
        headers: { 'Authorization' => 'Bearer xoxb-token' }
      },
      enabled: true
    )
    
    @disabled_fetcher = create_mcp_fetcher(
      name: 'experimental_ai',
      provider_type: 'http_api',
      description: 'Experimental AI provider (disabled by default)',
      configuration: {
        url: 'https://api.experimental-ai.com/predict'
      },
      enabled: false
    )
  end
  
  def test_global_mcp_fetcher_behavior
    service = McpWorkspaceService.new
    
    # Should have access to globally enabled fetchers
    enabled = service.enabled_fetchers
    enabled_names = enabled.map(&:name)
    
    assert_includes enabled_names, 'user_database'
    assert_includes enabled_names, 'slack_integration'
    refute_includes enabled_names, 'experimental_ai'
  end
  
  def test_workspace_specific_mcp_configuration
    # Engineering team wants to use all available fetchers
    engineering_service = McpWorkspaceService.new(@workspace1)
    
    # Initially inherits global settings
    assert engineering_service.mcp_fetcher_enabled?(@database_fetcher)
    assert engineering_service.mcp_fetcher_enabled?(@api_fetcher)
    refute engineering_service.mcp_fetcher_enabled?(@disabled_fetcher)
    
    # Enable experimental AI for engineering team only
    engineering_service.toggle_fetcher!(@disabled_fetcher)
    assert engineering_service.mcp_fetcher_enabled?(@disabled_fetcher)
    
    # Marketing team should still not have access to experimental AI
    marketing_service = McpWorkspaceService.new(@workspace2)
    refute marketing_service.mcp_fetcher_enabled?(@disabled_fetcher)
  end
  
  def test_context_fetching_workflow
    engineering_service = McpWorkspaceService.new(@workspace1)
    
    # Enable experimental AI for this workspace
    engineering_service.toggle_fetcher!(@disabled_fetcher)
    
    # Fetch context data
    user_data = engineering_service.fetch(:user_analytics, {
      fetcher_name: 'user_database',
      params: { workspace_id: @workspace1.id }
    })
    
    slack_data = engineering_service.fetch(:team_communication, {
      fetcher_name: 'slack_integration',
      params: { team_id: 'T123456' }
    })
    
    experimental_data = engineering_service.fetch(:ai_predictions, {
      fetcher_name: 'experimental_ai',
      params: { model: 'gpt-4', prompt: 'Analyze team productivity' }
    })
    
    # Verify all data was fetched successfully
    assert user_data
    assert_equal 'database', user_data[:type]
    
    assert slack_data
    assert_equal 'api', slack_data[:type]
    
    assert experimental_data
    assert_equal 'api', experimental_data[:type]
    
    # Verify context is available
    context = engineering_service.to_h
    assert_equal 3, context.keys.length
    assert context[:user_analytics]
    assert context[:team_communication]
    assert context[:ai_predictions]
  end
  
  def test_workspace_isolation
    # Engineering enables experimental AI
    engineering_service = McpWorkspaceService.new(@workspace1)
    engineering_service.toggle_fetcher!(@disabled_fetcher)
    
    # Engineering can access experimental AI
    result = engineering_service.fetch(:ai_data, { fetcher_name: 'experimental_ai' })
    refute result[:error]
    
    # Marketing cannot access experimental AI (still disabled globally)
    marketing_service = McpWorkspaceService.new(@workspace2)
    result = marketing_service.fetch(:ai_data, { fetcher_name: 'experimental_ai' })
    assert result[:error]
    assert_match(/disabled for workspace/i, result[:message])
  end
  
  def test_audit_logging
    service = McpWorkspaceService.new(@workspace1)
    
    # Perform some operations
    service.toggle_fetcher!(@database_fetcher)
    service.fetch(:test_data, { fetcher_name: 'user_database' })
    
    # Check audit entries
    audit_entries = service.audit_entries
    refute_empty audit_entries
    
    # Should have logged the toggle and the fetch
    toggle_entry = audit_entries.find { |e| e[:status] == 'toggle' }
    fetch_entry = audit_entries.find { |e| e[:status] == 'success' }
    
    assert toggle_entry
    assert_equal @workspace1.id, toggle_entry[:workspace_id]
    assert_equal @database_fetcher.id, toggle_entry[:fetcher_id]
    
    assert fetch_entry
    assert_equal @workspace1.id, fetch_entry[:workspace_id]
    assert_equal 'test_data', fetch_entry[:context_key]
    assert fetch_entry[:duration_ms]
  end
  
  def test_fetcher_status_reporting
    service = McpWorkspaceService.new(@workspace1)
    
    # Initially all fetchers inherit global status
    assert_equal 'Inherited (Enabled)', service.fetcher_status(@database_fetcher)
    assert_equal 'Inherited (Disabled)', service.fetcher_status(@disabled_fetcher)
    
    # After workspace toggle, status should reflect override
    service.toggle_fetcher!(@database_fetcher)
    service.toggle_fetcher!(@disabled_fetcher)
    
    # Note: This test relies on the mock implementation returning enabled=true after toggle
    # In real implementation, this would check the actual workspace override status
    assert_match(/workspace/i, service.fetcher_status(@database_fetcher))
    assert_match(/workspace/i, service.fetcher_status(@disabled_fetcher))
  end
  
  def test_error_handling_and_fallbacks
    service = McpWorkspaceService.new(@workspace1)
    
    # Try to fetch from non-existent fetcher
    result = service.fetch(:missing_data, { fetcher_name: 'non_existent' })
    assert result[:error]
    assert_match(/fetcher not found/i, result[:message])
    
    # Try to fetch from disabled fetcher
    result = service.fetch(:disabled_data, { fetcher_name: 'experimental_ai' })
    assert result[:error]
    assert_match(/disabled for workspace/i, result[:message])
    
    # Errors should be logged in audit
    error_entries = service.audit_entries.select { |e| e[:status] == 'error' }
    refute_empty error_entries
  end
  
  private
  
  def load_mcp_models
    # Load the service and models
    load File.expand_path('../../app/models/mcp_workspace_service.rb', __dir__)
    require_relative '../models/simple_mcp_workspace_service_test'
  end
  
  def create_workspace(name, slug)
    MockWorkspace.new(name: name, slug: slug)
  end
  
  def create_mcp_fetcher(attributes)
    MockMcpFetcher.create!(attributes)
  end
end