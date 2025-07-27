# frozen_string_literal: true

require 'test_helper'

class OpenaiFineTuningServiceTest < ActiveSupport::TestCase
  def setup
    @workspace = workspaces(:one)
    @user = users(:one)
    @ai_dataset = AiDataset.create!(
      name: 'Fine-tune Dataset',
      dataset_type: 'fine-tune',
      workspace: @workspace,
      created_by: @user
    )
  end

  test 'create_fine_tuning_job should process dataset' do
    # Mock file attachment
    @ai_dataset.stub(:files, [mock_file]) do
      @ai_dataset.stub(:can_process?, true) do
        result = OpenaiFineTuningService.create_fine_tuning_job(@ai_dataset)
        
        assert result.present?
        assert_equal 'processing', @ai_dataset.reload.processed_status
        assert @ai_dataset.metadata['openai_job_id'].present?
      end
    end
  end

  test 'create_fine_tuning_job should not process invalid dataset' do
    @ai_dataset.update!(dataset_type: 'embedding')
    
    result = OpenaiFineTuningService.create_fine_tuning_job(@ai_dataset)
    
    assert_nil result
    assert_equal 'pending', @ai_dataset.reload.processed_status
  end

  test 'check_job_status should update dataset status' do
    @ai_dataset.update!(
      processed_status: 'processing',
      metadata: { 'openai_job_id' => 'ftjob_test123' }
    )
    
    result = OpenaiFineTuningService.check_job_status(@ai_dataset)
    
    assert result.present?
    assert_equal 'completed', @ai_dataset.reload.processed_status
    assert @ai_dataset.metadata['fine_tuned_model'].present?
  end

  test 'list_fine_tuned_models should return completed datasets' do
    # Create completed fine-tune dataset
    completed_dataset = AiDataset.create!(
      name: 'Completed Dataset',
      dataset_type: 'fine-tune',
      processed_status: 'completed',
      workspace: @workspace,
      created_by: @user,
      metadata: { 'fine_tuned_model' => 'ft:gpt-3.5-turbo:test:abc123' }
    )
    
    models = OpenaiFineTuningService.list_fine_tuned_models(@workspace)
    
    assert_equal 1, models.size
    assert_equal completed_dataset.id, models.first[:dataset_id]
    assert_equal 'ft:gpt-3.5-turbo:test:abc123', models.first[:model_id]
  end

  test 'delete_fine_tuned_model should remove model reference' do
    @ai_dataset.update!(
      processed_status: 'completed',
      metadata: { 'fine_tuned_model' => 'ft:gpt-3.5-turbo:test:abc123' }
    )
    
    result = OpenaiFineTuningService.delete_fine_tuned_model(@ai_dataset)
    
    assert result
    assert_nil @ai_dataset.reload.metadata['fine_tuned_model']
  end

  test 'complete_with_fine_tuned_model should use custom model' do
    @ai_dataset.update!(
      processed_status: 'completed',
      metadata: { 'fine_tuned_model' => 'ft:gpt-3.5-turbo:test:abc123' }
    )
    
    response = OpenaiFineTuningService.complete_with_fine_tuned_model(
      @ai_dataset, 
      'Test prompt'
    )
    
    assert response.present?
    assert_includes response, 'ft:gpt-3.5-turbo:test:abc123'
  end

  test 'OpenaiClient should return mock responses' do
    client = OpenaiFineTuningService::OpenaiClient.new
    
    # Test file upload
    file_response = client.post('/files', { file: { content: 'test' } })
    assert file_response['id'].start_with?('file_')
    
    # Test job creation
    job_response = client.post('/fine_tuning/jobs', { model: 'gpt-3.5-turbo' })
    assert job_response['id'].start_with?('ftjob_')
    assert_equal 'queued', job_response['status']
    
    # Test job status check
    status_response = client.get('/fine_tuning/jobs/ftjob_test123')
    assert_equal 'succeeded', status_response['status']
    assert status_response['fine_tuned_model'].present?
  end

  private

  def mock_file
    file = Object.new
    file.define_singleton_method(:download) { '{"messages": [{"role": "user", "content": "test"}]}' }
    file.define_singleton_method(:filename) { 'test.jsonl' }
    file.define_singleton_method(:content_type) { 'application/json' }
    file
  end
end