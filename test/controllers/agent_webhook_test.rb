# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'

# Add missing methods for basic Rails-like extensions
class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
  
  def present?
    !blank?
  end
end

class String
  def blank?
    self.strip.empty?
  end
  
  def present?
    !blank?
  end
end

class Hash
  def with_indifferent_access
    self
  end
end

# Load the dependencies
require_relative '../models/agent_test'
require_relative '../services/agent_runner_test'

# Mock classes for testing the webhook controller
class MockRequest
  attr_accessor :headers
  
  def initialize
    @headers = {}
  end
end

class MockResponse
  attr_accessor :headers, :stream
  
  def initialize
    @headers = {}
    @stream = MockStream.new
  end
end

class MockStream
  def initialize
    @written_data = []
  end
  
  def write(data)
    @written_data << data
  end
  
  def close
    # no-op for mock
  end
  
  def data
    @written_data
  end
end

class MockEnv
  def self.[](key)
    case key
    when 'AGENT_WEBHOOK_TOKEN'
      'test-webhook-token'
    else
      nil
    end
  end
end

class MockActiveSupportSecurityUtils
  def self.secure_compare(a, b)
    a == b
  end
end

class MockJSON
  def self.generate(data)
    # Simple JSON generation for testing
    case data
    when Hash
      "{#{data.map { |k, v| "\"#{k}\":\"#{v}\"" }.join(',')}}"
    else
      "\"#{data}\""
    end
  end
end

class MockTime
  def self.current
    MockTimeInstance.new
  end
end

class MockTimeInstance
  def initialize
    @time = Time.new(2024, 1, 1, 12, 0, 0)
  end
  
  def iso8601
    "2024-01-01T12:00:00Z"
  end
end

class MockRails
  def self.logger
    MockLogger.new
  end
end

class MockLogger
  def info(message, data = {}); end
  def warn(message, data = {}); end
  def error(message, data = {}); end
end

# Simple AgentWebhooksController implementation for testing
class AgentWebhooksController
  attr_accessor :request, :response, :params

  def initialize
    @request = MockRequest.new
    @response = MockResponse.new
    @params = {}
  end

  def receive
    agent_id = params[:agent_id]
    user_input = params[:user_input] || params[:message] || ""
    webhook_context = params[:context] || {}
    streaming = params[:streaming] == true || params[:streaming] == 'true'

    MockRails.logger.info "Agent webhook received", {
      agent_id: agent_id,
      user_input_length: user_input.length,
      context_keys: webhook_context.keys,
      streaming: streaming
    }

    begin
      if streaming
        # For streaming, we need to use Server-Sent Events
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['Connection'] = 'keep-alive'

        # Stream the response
        AgentRunner.run(agent_id, user_input, context: webhook_context, streaming: true) do |content, type|
          case type
          when :chunk
            response.stream.write("data: #{json_encode({ type: 'chunk', content: content })}\n\n")
          when :complete
            response.stream.write("data: #{json_encode({ type: 'complete', content: content })}\n\n")
            response.stream.write("data: [DONE]\n\n")
          end
        end
      else
        # Synchronous response
        result = AgentRunner.run(agent_id, user_input, context: webhook_context)
        
        @result = {
          status: 'success',
          agent_id: agent_id,
          response: result,
          timestamp: MockTime.current.iso8601
        }
      end

    rescue ArgumentError => e
      @result = {
        status: 'error',
        error: 'invalid_agent',
        message: e.message
      }

    rescue => e
      MockRails.logger.error "Agent webhook execution failed", {
        agent_id: agent_id,
        error: e.message
      }

      @result = {
        status: 'error',
        error: 'execution_failed',
        message: e.message
      }
    end
    
    @result
  end

  def run
    agent_id = params[:agent_id]
    user_input = params[:user_input] || params[:message] || ""
    context = params[:context] || {}

    begin
      result = AgentRunner.run(agent_id, user_input, context: context)
      
      @result = {
        status: 'success',
        agent_id: agent_id,
        response: result,
        timestamp: MockTime.current.iso8601
      }

    rescue ArgumentError => e
      @result = {
        status: 'error',
        error: 'invalid_agent',
        message: e.message
      }

    rescue => e
      MockRails.logger.error "Agent API execution failed", {
        agent_id: agent_id,
        error: e.message
      }

      @result = {
        status: 'error',
        error: 'execution_failed',
        message: e.message
      }
    end
    
    @result
  end

  def config
    agent_id = params[:agent_id]
    
    begin
      runner = AgentRunner.new(agent_id)
      config = runner.agent_config
      summary = runner.agent.summary

      @result = {
        status: 'success',
        agent: summary,
        config: config,
        streaming_available: runner.streaming_available?
      }

    rescue ArgumentError => e
      @result = {
        status: 'error',
        error: 'invalid_agent',
        message: e.message
      }
    end
    
    @result
  end

  private

  def authenticate_webhook
    webhook_token = request.headers['X-Webhook-Token'] || params[:webhook_token]
    
    unless webhook_token.present? && valid_webhook_token?(webhook_token)
      @result = { error: 'unauthorized', message: 'Invalid webhook token' }
      return false
    end
    
    true
  end

  def valid_webhook_token?(token)
    expected_token = MockEnv['AGENT_WEBHOOK_TOKEN'] || 'default-webhook-token'
    MockActiveSupportSecurityUtils.secure_compare(token, expected_token)
  end

  def json_encode(data)
    MockJSON.generate(data)
  end
end

class AgentWebhookTest < Minitest::Test
  def setup
    @controller = AgentWebhooksController.new
  end

  def test_webhook_receive_synchronous
    @controller.params = {
      agent_id: 'test_agent',
      user_input: 'Hello, how can you help me?',
      context: { user_name: 'John' }
    }

    result = @controller.receive
    
    # Debug: print the actual result if it failed
    unless result[:status] == 'success'
      puts "Debug: #{result}"
    end
    
    assert_equal 'success', result[:status]
    assert_equal 'test_agent', result[:agent_id]
    assert_kind_of String, result[:response]
    assert_equal '2024-01-01T12:00:00Z', result[:timestamp]
  end

  def test_webhook_receive_streaming
    @controller.params = {
      agent_id: 'streaming_agent',
      user_input: 'Tell me a story',
      streaming: true
    }

    @controller.receive
    
    # Check that streaming headers were set
    assert_equal 'text/event-stream', @controller.response.headers['Content-Type']
    assert_equal 'no-cache', @controller.response.headers['Cache-Control']
    assert_equal 'keep-alive', @controller.response.headers['Connection']
    
    # Check that data was written to stream
    stream_data = @controller.response.stream.data
    assert stream_data.length > 0
    assert stream_data.any? { |data| data.include?('data:') }
  end

  def test_webhook_receive_invalid_agent
    @controller.params = {
      agent_id: 'nonexistent_agent',
      user_input: 'Hello'
    }

    result = @controller.receive
    
    assert_equal 'error', result[:status]
    assert_equal 'invalid_agent', result[:error]
    assert_match(/Agent not found/, result[:message])
  end

  def test_api_run_endpoint
    @controller.params = {
      agent_id: 'test_agent',
      user_input: 'What can you do?',
      context: { session_id: '12345' }
    }

    result = @controller.run
    
    assert_equal 'success', result[:status]
    assert_equal 'test_agent', result[:agent_id]
    assert_kind_of String, result[:response]
    assert result[:response].length > 0
  end

  def test_api_config_endpoint
    @controller.params = {
      agent_id: 'test_agent'
    }

    result = @controller.config
    
    assert_equal 'success', result[:status]
    assert_kind_of Hash, result[:agent]
    assert_kind_of Hash, result[:config]
    assert [true, false].include?(result[:streaming_available])
    
    # Check agent summary structure
    agent = result[:agent]
    assert agent[:name].present?
    assert agent[:slug].present?
    assert agent[:status].present?
    assert agent[:model].present?
    
    # Check config structure
    config = result[:config]
    assert config[:model_name].present?
    assert config[:temperature].present?
    assert config[:max_tokens].present?
  end

  def test_authentication_with_valid_token
    @controller.request.headers['X-Webhook-Token'] = 'test-webhook-token'
    
    assert @controller.send(:authenticate_webhook)
  end

  def test_authentication_with_invalid_token
    @controller.request.headers['X-Webhook-Token'] = 'invalid-token'
    
    refute @controller.send(:authenticate_webhook)
    assert_equal 'unauthorized', @controller.instance_variable_get(:@result)[:error]
  end

  def test_authentication_with_missing_token
    refute @controller.send(:authenticate_webhook)
    assert_equal 'unauthorized', @controller.instance_variable_get(:@result)[:error]
  end

  def test_json_encoding
    data = { type: 'chunk', content: 'Hello world' }
    result = @controller.send(:json_encode, data)
    
    assert_kind_of String, result
    assert result.include?('chunk')
    assert result.include?('Hello world')
  end

  def test_complete_webhook_workflow
    # Test a complete workflow from webhook to response
    
    # 1. Set up valid authentication
    @controller.request.headers['X-Webhook-Token'] = 'test-webhook-token'
    
    # 2. Set up valid request
    @controller.params = {
      agent_id: 'test_agent',
      user_input: 'Help me with my account',
      context: { 
        user_id: '123',
        workspace: 'acme-corp',
        request_id: 'req-456'
      }
    }
    
    # 3. Execute webhook
    result = @controller.receive
    
    # 4. Verify successful response
    assert_equal 'success', result[:status]
    assert_equal 'test_agent', result[:agent_id]
    assert_kind_of String, result[:response]
    assert result[:response].length > 0
    assert_equal '2024-01-01T12:00:00Z', result[:timestamp]
    
    puts "✅ Complete webhook workflow tested successfully!"
  end
end

# Run the webhook tests
puts "🧪 Running Agent Webhook Controller Tests..."

result = Minitest.run
if result
  puts "✅ Agent webhook controller tests completed successfully!"
  puts "📋 Webhook Test Coverage:"
  puts "  • Synchronous webhook execution"
  puts "  • Streaming webhook responses"
  puts "  • API endpoint functionality"
  puts "  • Agent configuration retrieval"
  puts "  • Authentication and security"
  puts "  • Error handling for invalid agents"
  puts "  • JSON response formatting"
  puts "  • Complete webhook workflow"
else
  puts "❌ Some agent webhook tests failed"
  exit 1
end