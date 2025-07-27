# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'

# Simple test framework setup for standalone testing
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
end

# Mock models for testing
class MockWorkspace
  attr_accessor :id, :name, :workspace_ai_config
  
  def initialize(id: 1, name: "Test Workspace")
    @id = id
    @name = name
  end
end

class MockUser
  attr_accessor :id, :name
  
  def initialize(id: 1, name: "Test User")
    @id = id
    @name = name
  end
end

class MockPromptTemplate
  attr_accessor :id, :slug, :name
  
  def initialize(id: 1, slug: "test_template", name: "Test Template")
    @id = id
    @slug = slug
    @name = name
  end
end

# Simple Agent class for testing (mimics the actual model)
class Agent
  attr_accessor :id, :name, :slug, :status, :model_name, :system_prompt, 
                :temperature, :max_tokens, :streaming_enabled, :webhook_enabled,
                :workspace, :created_by, :prompt_template, :config, :webhook_config

  DEFAULTS = {
    model_name: 'gpt-4',
    temperature: 0.7,
    max_tokens: 4096,
    streaming_enabled: false,
    webhook_enabled: false
  }.freeze

  SUPPORTED_MODELS = %w[
    gpt-3.5-turbo
    gpt-4
    gpt-4-turbo
    gpt-4o
    claude-3-haiku
    claude-3-sonnet
    claude-3-opus
  ].freeze

  def initialize(attributes = {})
    @id = attributes[:id] || 1
    @name = attributes[:name] || "Test Agent"
    @slug = attributes[:slug] || generate_slug_from_name(@name)
    @status = attributes[:status] || 'active'
    @model_name = attributes[:model_name] || DEFAULTS[:model_name]
    @system_prompt = attributes[:system_prompt] || "You are a helpful AI assistant."
    @temperature = attributes[:temperature] || DEFAULTS[:temperature]
    @max_tokens = attributes[:max_tokens] || DEFAULTS[:max_tokens]
    @streaming_enabled = attributes[:streaming_enabled] || DEFAULTS[:streaming_enabled]
    @webhook_enabled = attributes[:webhook_enabled] || DEFAULTS[:webhook_enabled]
    @workspace = attributes[:workspace] || MockWorkspace.new
    @created_by = attributes[:created_by] || MockUser.new
    @prompt_template = attributes[:prompt_template]
    @config = attributes[:config] || {}
    @webhook_config = attributes[:webhook_config] || {}
  end

  def effective_config
    DEFAULTS.merge({
      model_name: model_name,
      temperature: temperature,
      max_tokens: max_tokens,
      streaming_enabled: streaming_enabled,
      webhook_enabled: webhook_enabled,
      system_prompt: system_prompt,
      config: config,
      webhook_config: webhook_config
    })
  end

  def compiled_system_prompt(context = {})
    prompt_parts = []
    
    prompt_parts << system_prompt if system_prompt.present?
    
    if workspace.respond_to?(:workspace_ai_config) && workspace.workspace_ai_config&.instructions.present?
      prompt_parts << "\nWORKSPACE INSTRUCTIONS:"
      prompt_parts << workspace.workspace_ai_config.instructions
    end
    
    if context.present?
      context_str = context.map { |k, v| "#{k}: #{v}" }.join("\n")
      prompt_parts << "\nCONTEXT:"
      prompt_parts << context_str
    end
    
    prompt_parts.join("\n")
  end

  def api_key
    case model_name
    when /^gpt-/, /^claude-/
      if workspace.respond_to?(:workspace_ai_config) && workspace.workspace_ai_config&.respond_to?(:api_key)
        workspace.workspace_ai_config.api_key || 'test-api-key'
      else
        'test-api-key'
      end
    else
      'test-api-key'
    end
  end

  def ready?
    status == 'active' && 
    system_prompt.present? && 
    model_name.present? && 
    SUPPORTED_MODELS.include?(model_name)
  end

  def summary
    {
      id: id,
      name: name,
      slug: slug,
      status: status,
      model: model_name,
      workspace: workspace&.name,
      streaming: streaming_enabled,
      webhook: webhook_enabled,
      created_by: created_by&.name
    }
  end

  def generate_slug_from_name(name)
    name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
  end
end

class AgentTest < Minitest::Test
  def setup
    @workspace = MockWorkspace.new
    @user = MockUser.new
    @agent = Agent.new(
      name: "Test Agent",
      system_prompt: "You are a helpful AI assistant.",
      workspace: @workspace,
      created_by: @user
    )
  end

  def test_agent_initialization_with_defaults
    assert_equal "Test Agent", @agent.name
    assert_equal "test_agent", @agent.slug
    assert_equal "active", @agent.status
    assert_equal "gpt-4", @agent.model_name
    assert_equal 0.7, @agent.temperature
    assert_equal 4096, @agent.max_tokens
    assert_equal false, @agent.streaming_enabled
    assert_equal false, @agent.webhook_enabled
  end

  def test_agent_custom_initialization
    custom_agent = Agent.new(
      name: "Custom Agent",
      model_name: "gpt-4-turbo",
      temperature: 0.5,
      streaming_enabled: true
    )
    
    assert_equal "Custom Agent", custom_agent.name
    assert_equal "custom_agent", custom_agent.slug
    assert_equal "gpt-4-turbo", custom_agent.model_name
    assert_equal 0.5, custom_agent.temperature
    assert_equal true, custom_agent.streaming_enabled
  end

  def test_slug_generation
    agent = Agent.new(name: "My Special Agent!")
    assert_equal "my_special_agent", agent.slug
    
    agent = Agent.new(name: "  Agent with   Spaces  ")
    assert_equal "agent_with_spaces", agent.slug
  end

  def test_effective_config
    config = @agent.effective_config
    
    assert_equal "gpt-4", config[:model_name]
    assert_equal 0.7, config[:temperature]
    assert_equal 4096, config[:max_tokens]
    assert_equal false, config[:streaming_enabled]
    assert_equal false, config[:webhook_enabled]
    assert_equal "You are a helpful AI assistant.", config[:system_prompt]
  end

  def test_compiled_system_prompt_basic
    prompt = @agent.compiled_system_prompt
    assert_equal "You are a helpful AI assistant.", prompt
  end

  def test_compiled_system_prompt_with_context
    context = { user_name: "John", company: "Acme Corp" }
    prompt = @agent.compiled_system_prompt(context)
    
    expected = "You are a helpful AI assistant.\n\nCONTEXT:\nuser_name: John\ncompany: Acme Corp"
    assert_equal expected, prompt
  end

  def test_api_key_defaults
    assert_equal "test-api-key", @agent.api_key
  end

  def test_ready_status
    # Agent should be ready with default valid setup
    assert @agent.ready?
    
    # Agent should not be ready if inactive
    @agent.status = 'inactive'
    refute @agent.ready?
    
    # Agent should not be ready without system prompt
    @agent.status = 'active'
    @agent.system_prompt = ''
    refute @agent.ready?
    
    # Agent should not be ready with unsupported model
    @agent.system_prompt = "Test prompt"
    @agent.model_name = 'unsupported-model'
    refute @agent.ready?
  end

  def test_summary
    summary = @agent.summary
    
    assert_equal 1, summary[:id]
    assert_equal "Test Agent", summary[:name]
    assert_equal "test_agent", summary[:slug]
    assert_equal "active", summary[:status]
    assert_equal "gpt-4", summary[:model]
    assert_equal "Test Workspace", summary[:workspace]
    assert_equal false, summary[:streaming]
    assert_equal false, summary[:webhook]
    assert_equal "Test User", summary[:created_by]
  end

  def test_supported_models
    Agent::SUPPORTED_MODELS.each do |model|
      agent = Agent.new(model_name: model)
      assert agent.ready?, "Model #{model} should be supported"
    end
  end

  def test_model_validation
    unsupported_models = ['unsupported-model', 'random-model', '']
    
    unsupported_models.each do |model|
      agent = Agent.new(model_name: model)
      refute agent.ready?, "Model #{model} should not be supported"
    end
  end
end

# Run the tests
puts "🧪 Running Agent Model Tests..."

# Run the tests
result = Minitest.run
if result
  puts "✅ Agent model tests completed successfully!"
  puts "📋 Test Coverage:"
  puts "  • Model initialization and defaults"
  puts "  • Slug generation from names"
  puts "  • Configuration management"
  puts "  • System prompt compilation"
  puts "  • API key handling"
  puts "  • Ready status validation"
  puts "  • Model support verification"
  puts "  • Summary generation"
else
  puts "❌ Some agent model tests failed"
  exit 1
end