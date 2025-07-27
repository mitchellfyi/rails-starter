# frozen_string_literal: true

require 'test_helper'

class WorkspaceEmbeddingSourceTest < ActiveSupport::TestCase
  def setup
    @workspace = workspaces(:one)
    @user = users(:one)
    @ai_dataset = AiDataset.create!(
      name: 'Test Dataset',
      dataset_type: 'embedding',
      processed_status: 'completed',
      workspace: @workspace,
      created_by: @user
    )
    @embedding_source = WorkspaceEmbeddingSource.new(
      name: 'Test Source',
      description: 'A test embedding source',
      source_type: 'dataset',
      status: 'active',
      workspace: @workspace,
      ai_dataset: @ai_dataset,
      created_by: @user
    )
  end

  test 'should be valid with valid attributes' do
    assert @embedding_source.valid?
  end

  test 'should require name' do
    @embedding_source.name = nil
    assert_not @embedding_source.valid?
    assert_includes @embedding_source.errors[:name], "can't be blank"
  end

  test 'should require source_type' do
    @embedding_source.source_type = nil
    assert_not @embedding_source.valid?
    assert_includes @embedding_source.errors[:source_type], "can't be blank"
  end

  test 'should validate source_type inclusion' do
    @embedding_source.source_type = 'invalid'
    assert_not @embedding_source.valid?
    assert_includes @embedding_source.errors[:source_type], 'is not included in the list'
  end

  test 'should validate status inclusion' do
    @embedding_source.status = 'invalid'
    assert_not @embedding_source.valid?
    assert_includes @embedding_source.errors[:status], 'is not included in the list'
  end

  test 'should have default status of inactive' do
    source = WorkspaceEmbeddingSource.new
    assert_equal 'inactive', source.status
  end

  test 'ready? should return true when active and valid config' do
    @embedding_source.status = 'active'
    @embedding_source.source_type = 'dataset'
    assert @embedding_source.ready?
  end

  test 'ready? should return false when inactive' do
    @embedding_source.status = 'inactive'
    assert_not @embedding_source.ready?
  end

  test 'configuration should return hash with indifferent access' do
    config = { 'key' => 'value' }
    @embedding_source.config = config
    
    assert_equal 'value', @embedding_source.configuration['key']
    assert_equal 'value', @embedding_source.configuration[:key]
  end

  test 'namespace should return correct value for dataset source' do
    @embedding_source.source_type = 'dataset'
    @embedding_source.ai_dataset = @ai_dataset
    
    expected_namespace = "dataset_#{@ai_dataset.id}"
    assert_equal expected_namespace, @embedding_source.namespace
  end

  test 'namespace should return generic value for non-dataset source' do
    @embedding_source.source_type = 'manual'
    @embedding_source.ai_dataset = nil
    @embedding_source.id = 123
    
    expected_namespace = "source_123"
    assert_equal expected_namespace, @embedding_source.namespace
  end

  test 'test_connection should update status and last_tested_at' do
    @embedding_source.save!
    
    # Stub the get_embeddings method to return empty array
    @embedding_source.stub(:get_embeddings, []) do
      result = @embedding_source.test_connection
      
      assert result[:success]
      assert_equal 'Connection successful', result[:message]
      assert_equal 0, result[:result_count]
      assert_equal 'active', @embedding_source.reload.status
      assert_not_nil @embedding_source.last_tested_at
    end
  end

  test 'test_connection should handle errors' do
    @embedding_source.save!
    
    # Stub the get_embeddings method to raise an error
    @embedding_source.stub(:get_embeddings, -> { raise StandardError.new('Test error') }) do
      result = @embedding_source.test_connection
      
      assert_not result[:success]
      assert_equal 'Test error', result[:message]
      assert_equal 'error', @embedding_source.reload.status
      assert_not_nil @embedding_source.last_tested_at
    end
  end

  test 'scopes should work correctly' do
    active_source = WorkspaceEmbeddingSource.create!(
      name: 'Active Source',
      source_type: 'dataset',
      status: 'active',
      workspace: @workspace,
      created_by: @user
    )
    
    inactive_source = WorkspaceEmbeddingSource.create!(
      name: 'Inactive Source',
      source_type: 'manual',
      status: 'inactive',
      workspace: @workspace,
      created_by: @user
    )
    
    assert_includes WorkspaceEmbeddingSource.active, active_source
    assert_not_includes WorkspaceEmbeddingSource.active, inactive_source
    
    assert_includes WorkspaceEmbeddingSource.by_type('dataset'), active_source
    assert_not_includes WorkspaceEmbeddingSource.by_type('dataset'), inactive_source
    
    assert_includes WorkspaceEmbeddingSource.for_workspace(@workspace), active_source
    assert_includes WorkspaceEmbeddingSource.for_workspace(@workspace), inactive_source
  end

  test 'statistics should return correct data' do
    @embedding_source.save!
    
    # Mock VectorEmbedding.for_workspace to return a scope that responds to count
    mock_scope = mock('vector_embedding_scope')
    mock_scope.expects(:where).with(namespace: @embedding_source.namespace).returns(mock_scope)
    mock_scope.expects(:count).returns(5)
    
    VectorEmbedding.expects(:for_workspace).with(@workspace).returns(mock_scope)
    
    stats = @embedding_source.statistics
    
    assert_equal 5, stats[:embedding_count]
    assert_equal 'active', stats[:status]
    assert_equal 'dataset', stats[:source_type]
    assert_not_nil stats[:created_at]
  end

  private

  def mock(name)
    @mocks ||= {}
    @mocks[name] ||= Class.new do
      def initialize
        @expectations = {}
      end
      
      def expects(method)
        @expectations[method] = ExpectationDouble.new
      end
      
      class ExpectationDouble
        def with(*args)
          self
        end
        
        def returns(value)
          self
        end
      end
    end.new
  end
end