# frozen_string_literal: true

class AggregateUsageJob < ApplicationJob
  queue_as :default

  # Run daily to aggregate previous day's usage
  def perform(date = nil)
    date ||= Date.current - 1.day

    Rails.logger.info "Starting LLM usage aggregation for #{date}"
    
    begin
      aggregated_count = LlmUsage.aggregate_for_date(date)
      
      Rails.logger.info "Successfully aggregated #{aggregated_count} usage records for #{date}"
      
      # Also cleanup old aggregated data if needed (keep last 2 years)
      cleanup_old_usage_data
      
    rescue => e
      Rails.logger.error "Failed to aggregate usage for #{date}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end

  private

  def cleanup_old_usage_data
    cutoff_date = Date.current - 2.years
    deleted_count = LlmUsage.where('date < ?', cutoff_date).delete_all
    
    if deleted_count > 0
      Rails.logger.info "Cleaned up #{deleted_count} old usage records (older than #{cutoff_date})"
    end
  end
end