# frozen_string_literal: true

# Service for integrating with OpenAI's fine-tuning API
class OpenaiFineTuningService
  class << self
    # Initiate fine-tuning for a dataset
    def create_fine_tuning_job(ai_dataset, model: 'gpt-3.5-turbo', suffix: nil)
      return unless ai_dataset.dataset_type == 'fine-tune' && ai_dataset.can_process?

      ai_dataset.mark_processing!
      
      begin
        # Upload files to OpenAI
        file_ids = upload_files_to_openai(ai_dataset)
        
        # Create fine-tuning job
        job_response = create_openai_fine_tuning_job(
          training_file: file_ids.first,
          model: model,
          suffix: suffix
        )
        
        # Store job information in dataset metadata
        ai_dataset.update!(
          metadata: ai_dataset.metadata.merge(
            openai_job_id: job_response['id'],
            openai_model: model,
            openai_file_ids: file_ids,
            job_status: job_response['status']
          )
        )
        
        # Monitor job status (this would typically be done in a background job)
        monitor_fine_tuning_job(ai_dataset)
        
        job_response
      rescue => error
        ai_dataset.mark_failed!(error.message)
        raise
      end
    end

    # Check status of fine-tuning job
    def check_job_status(ai_dataset)
      job_id = ai_dataset.metadata['openai_job_id']
      return nil unless job_id

      response = openai_client.get("/fine_tuning/jobs/#{job_id}")
      
      # Update dataset status based on job status
      case response['status']
      when 'succeeded'
        ai_dataset.update!(
          processed_status: 'completed',
          metadata: ai_dataset.metadata.merge(
            fine_tuned_model: response['fine_tuned_model'],
            job_status: response['status']
          )
        )
      when 'failed', 'cancelled'
        ai_dataset.mark_failed!("Fine-tuning job #{response['status']}: #{response.dig('error', 'message')}")
      when 'running', 'queued'
        ai_dataset.update!(
          metadata: ai_dataset.metadata.merge(job_status: response['status'])
        )
      end
      
      response
    end

    # List available fine-tuned models for a workspace
    def list_fine_tuned_models(workspace)
      workspace.ai_datasets
               .where(dataset_type: 'fine-tune', processed_status: 'completed')
               .where("metadata->>'fine_tuned_model' IS NOT NULL")
               .map do |dataset|
        {
          dataset_id: dataset.id,
          dataset_name: dataset.name,
          model_id: dataset.metadata['fine_tuned_model'],
          created_at: dataset.processed_at
        }
      end
    end

    # Delete a fine-tuned model
    def delete_fine_tuned_model(ai_dataset)
      model_id = ai_dataset.metadata['fine_tuned_model']
      return false unless model_id

      begin
        openai_client.delete("/models/#{model_id}")
        
        # Update dataset metadata to remove model reference
        ai_dataset.update!(
          metadata: ai_dataset.metadata.except('fine_tuned_model')
        )
        
        true
      rescue => error
        Rails.logger.error "Failed to delete fine-tuned model #{model_id}: #{error.message}"
        false
      end
    end

    # Use fine-tuned model for completion
    def complete_with_fine_tuned_model(ai_dataset, prompt, **options)
      model_id = ai_dataset.metadata['fine_tuned_model']
      return nil unless model_id

      response = openai_client.post('/chat/completions', {
        model: model_id,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: options[:max_tokens] || 256,
        temperature: options[:temperature] || 0.7
      })

      response.dig('choices', 0, 'message', 'content')
    end

    private

    def upload_files_to_openai(ai_dataset)
      file_ids = []
      
      ai_dataset.files.each do |file|
        content = file.download
        
        # Validate file format for fine-tuning
        unless valid_fine_tuning_format?(content, file.content_type)
          raise "Invalid file format for fine-tuning: #{file.filename}"
        end
        
        # Upload to OpenAI
        response = openai_client.post('/files', {
          file: {
            content: content,
            filename: file.filename.to_s,
            content_type: file.content_type
          },
          purpose: 'fine-tune'
        })
        
        file_ids << response['id']
      end
      
      file_ids
    end

    def create_openai_fine_tuning_job(training_file:, model:, suffix: nil)
      params = {
        training_file: training_file,
        model: model
      }
      
      params[:suffix] = suffix if suffix.present?
      
      openai_client.post('/fine_tuning/jobs', params)
    end

    def monitor_fine_tuning_job(ai_dataset)
      # In a real implementation, this would be a background job
      # that periodically checks the job status
      Rails.logger.info "Monitoring fine-tuning job for dataset #{ai_dataset.id}"
      
      # For now, we'll just simulate completion after a delay
      if Rails.env.development?
        sleep(2)
        ai_dataset.update!(
          processed_status: 'completed',
          metadata: ai_dataset.metadata.merge(
            fine_tuned_model: "ft:gpt-3.5-turbo:#{ai_dataset.workspace.slug}:#{ai_dataset.id}:#{Time.current.to_i}",
            job_status: 'succeeded'
          )
        )
      end
    end

    def valid_fine_tuning_format?(content, content_type)
      return false unless content_type == 'application/json' || content_type == 'text/plain'
      
      # For JSONL format, each line should be valid JSON with required fields
      if content_type == 'application/json' || content.include?("\n")
        lines = content.split("\n").reject(&:blank?)
        return false if lines.empty?
        
        lines.each do |line|
          begin
            data = JSON.parse(line)
            # Check for required fields (this is simplified)
            return false unless data.key?('messages') || (data.key?('prompt') && data.key?('completion'))
          rescue JSON::ParserError
            return false
          end
        end
      end
      
      true
    end

    def openai_client
      @openai_client ||= OpenaiClient.new
    end
  end

  # Mock OpenAI client for development/testing
  class OpenaiClient
    def initialize
      @api_key = ENV['OPENAI_API_KEY'] || 'test-key'
      @base_url = 'https://api.openai.com/v1'
    end

    def post(endpoint, params)
      # In a real implementation, this would make HTTP requests to OpenAI
      # For now, return mock responses
      case endpoint
      when '/files'
        { 'id' => "file_#{SecureRandom.hex(8)}", 'purpose' => 'fine-tune' }
      when '/fine_tuning/jobs'
        {
          'id' => "ftjob_#{SecureRandom.hex(8)}",
          'status' => 'queued',
          'model' => params[:model],
          'training_file' => params[:training_file]
        }
      when '/chat/completions'
        {
          'choices' => [
            {
              'message' => {
                'content' => "This is a response from fine-tuned model #{params[:model]}"
              }
            }
          ]
        }
      else
        {}
      end
    end

    def get(endpoint)
      # Mock responses for GET requests
      case endpoint
      when %r{/fine_tuning/jobs/(.+)}
        job_id = $1
        {
          'id' => job_id,
          'status' => 'succeeded',
          'fine_tuned_model' => "ft:gpt-3.5-turbo:test:#{SecureRandom.hex(4)}",
          'created_at' => Time.current.to_i
        }
      else
        {}
      end
    end

    def delete(endpoint)
      # Mock responses for DELETE requests
      { 'deleted' => true }
    end
  end
end