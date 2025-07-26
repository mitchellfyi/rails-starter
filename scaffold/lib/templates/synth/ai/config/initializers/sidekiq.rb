# frozen_string_literal: true

# Sidekiq configuration for LLM jobs
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
  
  # Configure queues with weights
  # Default queue handles LLM jobs with normal priority
  # High priority queue for urgent LLM requests
  # Low priority queue for batch operations
  config.queues = %w[high default low]
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
end

# Configure job-specific options
Sidekiq.default_job_options = {
  'retry' => 5,
  'backtrace' => true,
  'queue' => 'default'
}

# Death handlers for failed jobs
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, ex) do
    # Log final failure
    Rails.logger.error "Job permanently failed after all retries", {
      job_class: job['class'],
      job_id: job['jid'],
      args: job['args'],
      error: ex.class.name,
      message: ex.message,
      retry_count: job['retry_count'] || 0
    }

    # Update LLMOutput status if it's an LLMJob
    if job['class'] == 'LLMJob' && job['jid']
      begin
        llm_output = LLMOutput.find_by(job_id: job['jid'])
        if llm_output
          llm_output.update!(
            status: 'failed',
            raw_response: "Job failed permanently: #{ex.message}"
          )
        end
      rescue => e
        Rails.logger.error "Failed to update LLMOutput status: #{e.message}"
      end
    end
  end
end