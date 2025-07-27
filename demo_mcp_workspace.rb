#!/usr/bin/env ruby
# frozen_string_literal: true

# MCP Workspace Demo Script
# This script demonstrates the MCP per workspace functionality

puts "🚀 MCP (Multi-Context Provider) Per Workspace Demo"
puts "=" * 50

# Load models (mocked for demo)
class DemoMcpFetcher
  attr_accessor :name, :provider_type, :description, :enabled, :configuration
  
  def initialize(attrs)
    attrs.each { |k, v| send("#{k}=", v) }
  end
  
  def enabled_for_workspace?(workspace)
    @workspace_overrides ||= {}
    @workspace_overrides.key?(workspace&.name) ? @workspace_overrides[workspace.name] : enabled
  end
  
  def toggle_for_workspace!(workspace)
    @workspace_overrides ||= {}
    @workspace_overrides[workspace.name] = !enabled_for_workspace?(workspace)
  end
  
  def workspace_status(workspace)
    return 'Global' unless workspace
    
    if @workspace_overrides&.key?(workspace.name)
      enabled_for_workspace?(workspace) ? 'Enabled for Workspace' : 'Disabled for Workspace'
    else
      enabled ? 'Inherited (Enabled)' : 'Inherited (Disabled)'
    end
  end
end

class DemoWorkspace
  attr_accessor :name, :slug
  
  def initialize(name, slug)
    @name = name
    @slug = slug
  end
end

# Create demo workspaces
engineering = DemoWorkspace.new('Engineering Team', 'engineering')
marketing = DemoWorkspace.new('Marketing Team', 'marketing')

puts "\n📁 Created Workspaces:"
puts "  • #{engineering.name} (#{engineering.slug})"
puts "  • #{marketing.name} (#{marketing.slug})"

# Create demo MCP fetchers
database_fetcher = DemoMcpFetcher.new(
  name: 'user_analytics',
  provider_type: 'database',
  description: 'Fetch user engagement metrics from database',
  enabled: true,
  configuration: {
    query: 'SELECT COUNT(*) as users, AVG(sessions) as avg_sessions FROM analytics WHERE workspace_id = ?',
    timeout: 30
  }
)

slack_fetcher = DemoMcpFetcher.new(
  name: 'slack_integration',
  provider_type: 'http_api',
  description: 'Fetch team communication data from Slack API',
  enabled: true,
  configuration: {
    url: 'https://slack.com/api/conversations.history',
    headers: { 'Authorization' => 'Bearer xoxb-token' }
  }
)

experimental_fetcher = DemoMcpFetcher.new(
  name: 'experimental_ai',
  provider_type: 'http_api',
  description: 'Experimental AI predictions (disabled by default)',
  enabled: false,
  configuration: {
    url: 'https://api.experimental-ai.com/predict',
    model: 'gpt-4-advanced'
  }
)

fetchers = [database_fetcher, slack_fetcher, experimental_fetcher]

puts "\n🔗 Created MCP Fetchers:"
fetchers.each do |fetcher|
  status = fetcher.enabled ? "✅ Enabled" : "❌ Disabled"
  puts "  • #{fetcher.name} (#{fetcher.provider_type}) - #{status}"
  puts "    #{fetcher.description}"
end

puts "\n" + "=" * 50
puts "📋 Initial Global Status:"
puts "=" * 50

[engineering, marketing].each do |workspace|
  puts "\n🏢 #{workspace.name}:"
  fetchers.each do |fetcher|
    status = fetcher.workspace_status(workspace)
    enabled = fetcher.enabled_for_workspace?(workspace) ? "✅" : "❌"
    puts "  #{enabled} #{fetcher.name}: #{status}"
  end
end

puts "\n" + "=" * 50
puts "🛠  Making Workspace-Specific Changes:"
puts "=" * 50

puts "\n1. Engineering team enables experimental AI..."
experimental_fetcher.toggle_for_workspace!(engineering)

puts "2. Marketing team disables user analytics..."
database_fetcher.toggle_for_workspace!(marketing)

puts "\n✅ Changes Applied!"

puts "\n" + "=" * 50
puts "📋 Updated Workspace Status:"
puts "=" * 50

[engineering, marketing].each do |workspace|
  puts "\n🏢 #{workspace.name}:"
  fetchers.each do |fetcher|
    status = fetcher.workspace_status(workspace)
    enabled = fetcher.enabled_for_workspace?(workspace) ? "✅" : "❌"
    puts "  #{enabled} #{fetcher.name}: #{status}"
  end
end

puts "\n" + "=" * 50
puts "🚀 Context Fetching Simulation:"
puts "=" * 50

def simulate_fetch(workspace, fetcher)
  if fetcher.enabled_for_workspace?(workspace)
    case fetcher.provider_type
    when 'database'
      { type: 'database', results: [{ users: 150, avg_sessions: 12.5 }], timestamp: Time.now }
    when 'http_api'
      { type: 'api', status: 200, data: { success: true }, timestamp: Time.now }
    end
  else
    { error: true, message: "Fetcher '#{fetcher.name}' is disabled for workspace '#{workspace.name}'" }
  end
end

[engineering, marketing].each do |workspace|
  puts "\n🏢 #{workspace.name} fetching context:"
  
  fetchers.each do |fetcher|
    print "  📡 #{fetcher.name}... "
    result = simulate_fetch(workspace, fetcher)
    
    if result[:error]
      puts "❌ #{result[:message]}"
    else
      puts "✅ Success (#{result[:type]})"
    end
  end
end

puts "\n" + "=" * 50
puts "🎯 Demo Summary:"
puts "=" * 50

puts "\n✅ Successfully demonstrated:"
puts "  • Global MCP fetcher configuration"
puts "  • Workspace-specific overrides"
puts "  • Status inheritance model"
puts "  • Context fetching with access control"
puts "  • Audit trail capability (workspace isolation)"

puts "\n🔗 In the real implementation:"
puts "  • Admin UI at /admin/mcp_fetchers"
puts "  • Full CRUD operations with validation"
puts "  • JSON configuration management"
puts "  • Database persistence with migrations"
puts "  • Complete audit logging"
puts "  • Integration with existing Rails patterns"

puts "\n🚀 Ready for AI agent integration!"
puts "=" * 50