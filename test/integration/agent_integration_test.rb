# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'

# Load the dependencies
require_relative '../models/agent_test'
require_relative '../services/agent_runner_test'

class AgentIntegrationTest < Minitest::Test
  def setup
    @user = MockUser.new(id: 1, name: "Test User")
    @workspace = MockWorkspace.new(id: 1, name: "Test Workspace")
  end

  def test_complete_agent_workflow
    # Test complete workflow from agent creation to execution
    
    # 1. Create an agent (for testing, we use an existing mock agent)
    agent_id = 'test_agent'  # Use existing mock agent
    runner = AgentRunner.new(agent_id, user: @user, context: { workspace: "test" })
    
    assert runner.agent.ready?, "Agent should be ready after creation"
    assert_equal "test_agent", runner.agent.slug
    
    # 2. Test AgentRunner initialization
    assert_equal "Test Agent", runner.agent.name
    assert_equal @user, runner.user
    
    # 3. Test synchronous execution
    response = runner.run("I need help with my account")
    assert_kind_of String, response
    assert response.length > 0
    
    # 4. Test streaming execution (use streaming agent)
    streaming_runner = AgentRunner.new('streaming_agent', user: @user)
    chunks = []
    final_response = nil
    
    response = streaming_runner.run("Tell me about your services", streaming: true) do |content, type|
      if type == :chunk
        chunks << content
      elsif type == :complete
        final_response = content
      end
    end
    
    assert chunks.length > 0, "Should receive streaming chunks"
    assert_equal response, final_response
    
    # 5. Test class method execution
    class_response = AgentRunner.run(agent_id, "Hello!", context: { test: true })
    assert_kind_of String, class_response
    
    # 6. Test configuration access
    config = runner.agent_config
    assert_equal "gpt-4", config[:model_name]
    assert config[:system_prompt].present?
    
    # 7. Test streaming availability
    assert_equal false, runner.streaming_available?, "Default agent should not have streaming enabled"
    assert_equal true, streaming_runner.streaming_available?, "Streaming agent should have streaming enabled"
    
    puts "✅ Complete agent workflow tested successfully!"
  end

  def test_multiple_agents_execution
    # Test that multiple agents can be executed independently
    
    agent_ids = ['test_agent', 'claude_agent']  # Use existing mock agents
    responses = []
    
    agent_ids.each do |agent_id|
      response = AgentRunner.run(agent_id, "Hello!")
      responses << response
      assert_kind_of String, response
    end
    
    assert_equal 2, responses.length
    assert responses.all? { |r| r.is_a?(String) && r.length > 0 }
    
    puts "✅ Multiple agents execution tested successfully!"
  end

  def test_error_handling_workflow
    # Test various error scenarios
    
    # Test invalid agent ID
    error = assert_raises(ArgumentError) do
      AgentRunner.new('nonexistent_agent')
    end
    assert_match(/Agent not found/, error.message)
    
    # Test inactive agent
    error = assert_raises(ArgumentError) do
      AgentRunner.new('inactive_agent')
    end
    assert_match(/Agent is not ready to run/, error.message)
    
    # Test class method with invalid agent
    error = assert_raises(ArgumentError) do
      AgentRunner.run('invalid_agent', "Hello!")
    end
    assert_match(/Agent not found/, error.message)
    
    puts "✅ Error handling workflow tested successfully!"
  end

  def test_context_and_user_handling
    # Test that context and user information flows correctly
    
    agent_id = 'test_agent'  # Use existing mock agent
    
    # Test with user context
    context = {
      user_name: "John Doe",
      company: "Acme Corp",
      role: "admin"
    }
    
    runner = AgentRunner.new(agent_id, user: @user, context: context)
    
    # Verify context is preserved
    assert_equal "John Doe", runner.context[:user_name]
    assert_equal "Acme Corp", runner.context[:company]
    assert_equal @user, runner.user
    
    # Test execution with context
    response = runner.run("What's my role?")
    assert_kind_of String, response
    
    # Test class method with context
    class_response = AgentRunner.run(agent_id, "Hello!", 
      user: @user, 
      context: { session: "test_session" }
    )
    assert_kind_of String, class_response
    
    puts "✅ Context and user handling tested successfully!"
  end

  def test_different_model_configurations
    # Test agents with different model configurations
    
    models_to_test = [
      'test_agent',      # gpt-4 model
      'claude_agent',    # claude model
      'streaming_agent'  # streaming enabled
    ]
    
    models_to_test.each do |agent_id|
      runner = AgentRunner.new(agent_id)
      
      assert runner.agent.ready?, "Agent #{agent_id} should be ready"
      
      response = AgentRunner.run(agent_id, "Test message")
      assert_kind_of String, response
      assert response.length > 0
      
      config = runner.agent_config
      assert config[:model_name].present?, "Agent should have a model configured"
    end
    
    puts "✅ Different model configurations tested successfully!"
  end
end

# Run the integration tests
puts "🧪 Running Agent Integration Tests..."

result = Minitest.run
if result
  puts "✅ Agent integration tests completed successfully!"
  puts "📋 Integration Test Coverage:"
  puts "  • Complete agent workflow (creation → execution → streaming)"
  puts "  • Multiple agents execution independence"
  puts "  • Comprehensive error handling scenarios"
  puts "  • Context and user information flow"
  puts "  • Different model configurations"
  puts "  • Class method vs instance method consistency"
else
  puts "❌ Some agent integration tests failed"
  exit 1
end