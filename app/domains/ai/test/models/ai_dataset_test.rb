# frozen_string_literal: true

require 'test_helper'

class AiDatasetTest < ActiveSupport::TestCase
  def setup
    @workspace = workspaces(:one)
    @user = users(:one)
    @ai_dataset = AiDataset.new(
      name: 'Test Dataset',
      description: 'A test dataset for embeddings',
      dataset_type: 'embedding',
      workspace: @workspace,
      created_by: @user
    )
  end

  test 'should be valid with valid attributes' do
    assert @ai_dataset.valid?
  end

  test 'should require name' do
    @ai_dataset.name = nil
    assert_not @ai_dataset.valid?
    assert_includes @ai_dataset.errors[:name], "can't be blank"
  end

  test 'should require dataset_type' do
    @ai_dataset.dataset_type = nil
    assert_not @ai_dataset.valid?
    assert_includes @ai_dataset.errors[:dataset_type], "can't be blank"
  end

  test 'should validate dataset_type inclusion' do
    @ai_dataset.dataset_type = 'invalid'
    assert_not @ai_dataset.valid?
    assert_includes @ai_dataset.errors[:dataset_type], 'is not included in the list'
  end

  test 'should validate processed_status inclusion' do
    @ai_dataset.processed_status = 'invalid'
    assert_not @ai_dataset.valid?
    assert_includes @ai_dataset.errors[:processed_status], 'is not included in the list'
  end

  test 'should have default processed_status of pending' do
    dataset = AiDataset.new
    assert_equal 'pending', dataset.processed_status
  end

  test 'ready? should return true when completed' do
    @ai_dataset.processed_status = 'completed'
    assert @ai_dataset.ready?
  end

  test 'ready? should return false when not completed' do
    @ai_dataset.processed_status = 'pending'
    assert_not @ai_dataset.ready?
  end

  test 'processing? should return true when processing' do
    @ai_dataset.processed_status = 'processing'
    assert @ai_dataset.processing?
  end

  test 'can_process? should return true for pending with files' do
    @ai_dataset.processed_status = 'pending'
    @ai_dataset.stub(:files, [double('file')]) do
      assert @ai_dataset.can_process?
    end
  end

  test 'can_process? should return false without files' do
    @ai_dataset.processed_status = 'pending'
    @ai_dataset.stub(:files, []) do
      assert_not @ai_dataset.can_process?
    end
  end

  test 'mark_processing! should update status and timestamp' do
    @ai_dataset.save!
    @ai_dataset.mark_processing!
    
    assert_equal 'processing', @ai_dataset.processed_status
    assert_not_nil @ai_dataset.processed_at
  end

  test 'mark_completed! should update status and timestamp' do
    @ai_dataset.save!
    @ai_dataset.mark_completed!
    
    assert_equal 'completed', @ai_dataset.processed_status
    assert_not_nil @ai_dataset.processed_at
  end

  test 'mark_failed! should update status, timestamp and error message' do
    @ai_dataset.save!
    error_message = 'Test error'
    @ai_dataset.mark_failed!(error_message)
    
    assert_equal 'failed', @ai_dataset.processed_status
    assert_not_nil @ai_dataset.processed_at
    assert_equal error_message, @ai_dataset.error_message
  end

  test 'scopes should work correctly' do
    embedding_dataset = AiDataset.create!(
      name: 'Embedding Dataset',
      dataset_type: 'embedding',
      workspace: @workspace,
      created_by: @user
    )
    
    finetune_dataset = AiDataset.create!(
      name: 'Fine-tune Dataset',
      dataset_type: 'fine-tune',
      workspace: @workspace,
      created_by: @user
    )
    
    assert_includes AiDataset.by_type('embedding'), embedding_dataset
    assert_not_includes AiDataset.by_type('embedding'), finetune_dataset
    
    assert_includes AiDataset.for_workspace(@workspace), embedding_dataset
    assert_includes AiDataset.for_workspace(@workspace), finetune_dataset
  end

  test 'processing_stats should return correct data' do
    @ai_dataset.save!
    @ai_dataset.stub(:file_count, 2) do
      @ai_dataset.stub(:total_file_size, 1024) do
        stats = @ai_dataset.processing_stats
        
        assert_equal 2, stats[:file_count]
        assert_equal 1024, stats[:total_size]
        assert_equal 'pending', stats[:status]
        assert_not_nil stats[:created_at]
      end
    end
  end
end