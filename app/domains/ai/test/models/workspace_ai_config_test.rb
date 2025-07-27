# frozen_string_literal: true

require 'test_helper'

class WorkspaceAiConfigTest < ActiveSupport::TestCase
  def setup
    @workspace = workspaces(:one)
    @user = users(:one)
    @ai_config = WorkspaceAiConfig.new(
      workspace: @workspace,
      updated_by: @user,
      instructions: 'Test instructions',
      rag_enabled: true,
      embedding_model: 'text-embedding-ada-002',
      chat_model: 'gpt-4',
      temperature: 0.7,
      max_tokens: 4096
    )
  end

  test 'should be valid with valid attributes' do
    assert @ai_config.valid?
  end

  test 'should require embedding_model' do
    @ai_config.embedding_model = nil
    assert_not @ai_config.valid?
    assert_includes @ai_config.errors[:embedding_model], "can't be blank"
  end

  test 'should require chat_model' do
    @ai_config.chat_model = nil
    assert_not @ai_config.valid?
    assert_includes @ai_config.errors[:chat_model], "can't be blank"
  end

  test 'should validate temperature range' do
    @ai_config.temperature = -0.1
    assert_not @ai_config.valid?
    assert_includes @ai_config.errors[:temperature], 'must be greater than or equal to 0.0'

    @ai_config.temperature = 2.1
    assert_not @ai_config.valid?
    assert_includes @ai_config.errors[:temperature], 'must be less than or equal to 2.0'
  end

  test 'should validate max_tokens range' do
    @ai_config.max_tokens = 0
    assert_not @ai_config.valid?
    assert_includes @ai_config.errors[:max_tokens], 'must be greater than 0'

    @ai_config.max_tokens = 32001
    assert_not @ai_config.valid?
    assert_includes @ai_config.errors[:max_tokens], 'must be less than or equal to 32000'
  end

  test 'should validate instructions length' do
    @ai_config.instructions = 'a' * 10001
    assert_not @ai_config.valid?
    assert_includes @ai_config.errors[:instructions], 'is too long (maximum is 10000 characters)'
  end

  test 'should set defaults on initialization' do
    config = WorkspaceAiConfig.new
    
    assert_equal WorkspaceAiConfig::DEFAULTS[:embedding_model], config.embedding_model
    assert_equal WorkspaceAiConfig::DEFAULTS[:chat_model], config.chat_model
    assert_equal WorkspaceAiConfig::DEFAULTS[:temperature], config.temperature
    assert_equal WorkspaceAiConfig::DEFAULTS[:max_tokens], config.max_tokens
    assert_equal WorkspaceAiConfig::DEFAULTS[:rag_enabled], config.rag_enabled
  end

  test 'rag_config should return hash with indifferent access' do
    config = { 'key' => 'value' }
    @ai_config.rag_config = config
    
    assert_equal 'value', @ai_config.rag_config['key']
    assert_equal 'value', @ai_config.rag_config[:key]
  end

  test 'model_config should return hash with indifferent access' do
    config = { 'top_p' => 0.9 }
    @ai_config.model_config = config
    
    assert_equal 0.9, @ai_config.model_config['top_p']
    assert_equal 0.9, @ai_config.model_config[:top_p]
  end

  test 'tools_config should return hash with indifferent access' do
    config = { 'enabled_tools' => ['calculator'] }
    @ai_config.tools_config = config
    
    assert_equal ['calculator'], @ai_config.tools_config['enabled_tools']
    assert_equal ['calculator'], @ai_config.tools_config[:enabled_tools]
  end

  test 'effective_config should merge defaults with overrides' do
    @ai_config.temperature = 0.5
    effective = @ai_config.effective_config
    
    assert_equal 0.5, effective[:temperature]
    assert_equal 'gpt-4', effective[:chat_model]
    assert_equal true, effective[:rag_enabled]
    assert_equal 'Test instructions', effective[:instructions]
  end

  test 'effective_rag_config should return correct values' do
    @ai_config.rag_config = { 'semantic_search_threshold' => 0.8 }
    rag_config = @ai_config.effective_rag_config
    
    assert_equal true, rag_config[:enabled]
    assert_equal 0.8, rag_config[:semantic_search_threshold]
    assert_equal WorkspaceAiConfig::DEFAULTS[:max_context_chunks], rag_config[:max_context_chunks]
  end

  test 'effective_model_config should return correct values' do
    @ai_config.model_config = { 'top_p' => 0.9 }
    model_config = @ai_config.effective_model_config
    
    assert_equal 0.7, model_config[:temperature]
    assert_equal 0.9, model_config[:top_p]
    assert_equal 0.0, model_config[:frequency_penalty]
  end

  test 'effective_tools_config should return correct values' do
    @ai_config.tools_config = { 'enabled_tools' => ['calculator'] }
    tools_config = @ai_config.effective_tools_config
    
    assert_equal ['calculator'], tools_config[:enabled_tools]
    assert_equal 'auto', tools_config[:tool_choice]
    assert_equal true, tools_config[:parallel_tool_calls]
  end

  test 'build_rag_context should return empty when rag disabled' do
    @ai_config.rag_enabled = false
    result = @ai_config.build_rag_context('test query')
    
    assert_equal '', result[:context]
    assert_equal [], result[:sources]
  end

  test 'build_rag_context should process active embedding sources' do
    @ai_config.save!
    
    # Mock workspace embedding sources
    mock_source = mock('embedding_source')
    mock_source.expects(:get_embeddings).returns([
      { content: 'test content', similarity_score: 0.9, metadata: {} }
    ])
    mock_source.expects(:id).returns(1)
    mock_source.expects(:name).returns('Test Source')
    mock_source.expects(:source_type).returns('dataset')
    
    @workspace.expects(:workspace_embedding_sources).returns(mock('relation'))
    @workspace.workspace_embedding_sources.expects(:active).returns([mock_source])
    
    result = @ai_config.build_rag_context('test query')
    
    assert_includes result[:context], 'test content'
    assert_equal 1, result[:sources].size
    assert_equal 1, result[:chunks_used]
  end

  test 'format_system_prompt should include instructions' do
    prompt = @ai_config.format_system_prompt
    
    assert_includes prompt, 'WORKSPACE INSTRUCTIONS:'
    assert_includes prompt, 'Test instructions'
  end

  test 'format_system_prompt should include context when provided' do
    context = 'relevant context here'
    prompt = @ai_config.format_system_prompt(context: context)
    
    assert_includes prompt, 'RELEVANT CONTEXT:'
    assert_includes prompt, context
    assert_includes prompt, 'Use the above context'
  end

  test 'summary should return correct data' do
    @ai_config.save!
    
    # Mock workspace embedding sources
    @workspace.expects(:workspace_embedding_sources).returns(mock('relation'))
    @workspace.workspace_embedding_sources.expects(:active).returns(mock('relation'))
    @workspace.workspace_embedding_sources.active.expects(:count).returns(2)
    
    summary = @ai_config.summary
    
    assert_equal 'gpt-4', summary[:models][:chat]
    assert_equal 'text-embedding-ada-002', summary[:models][:embedding]
    assert_equal 0.7, summary[:settings][:temperature]
    assert_equal 4096, summary[:settings][:max_tokens]
    assert_equal true, summary[:settings][:rag_enabled]
    assert_equal 2, summary[:sources]
  end

  private

  def mock(name)
    @mocks ||= {}
    @mocks[name] ||= Class.new do
      def initialize
        @expectations = {}
      end
      
      def expects(method)
        @expectations[method] = ExpectationDouble.new(self)
      end
      
      def method_missing(method, *args)
        if @expectations[method]
          @expectations[method]
        else
          super
        end
      end
      
      class ExpectationDouble
        def initialize(parent)
          @parent = parent
        end
        
        def returns(value)
          define_singleton_method(:call) { value }
          @parent.define_singleton_method(@method) { value }
          self
        end
        
        def with(*args)
          self
        end
      end
    end.new
  end
end