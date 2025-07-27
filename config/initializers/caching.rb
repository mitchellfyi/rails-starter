# frozen_string_literal: true

# Caching configuration for Rails SaaS Starter Template
# Configures Redis as the cache store for better performance

Rails.application.configure do
  # Use Redis for caching in development and production
  if Rails.env.development? || Rails.env.production?
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
      namespace: Rails.application.class.module_parent_name.underscore,
      expires_in: 1.hour,
      compress: true,
      pool_size: 5,
      pool_timeout: 5
    }
  end
  
  # Enable fragment caching in development for testing
  config.action_controller.perform_caching = true if Rails.env.development?
  
  # Configure cache key versioning
  config.active_record.cache_versioning = true
  
  Rails.logger.info "🚀 Cache store configured: #{config.cache_store.class.name}"
end

# Helper methods for common caching patterns
module CacheHelpers
  # Cache workspace-related data with proper invalidation
  def cache_workspace_data(workspace, key, expires_in: 1.hour, &block)
    Rails.cache.fetch("workspace:#{workspace.id}:#{key}", expires_in: expires_in, &block)
  end
  
  # Cache user-specific data
  def cache_user_data(user, key, expires_in: 30.minutes, &block)
    Rails.cache.fetch("user:#{user.id}:#{key}", expires_in: expires_in, &block)
  end
  
  # Cache expensive API calls
  def cache_api_response(endpoint, params = {}, expires_in: 5.minutes, &block)
    cache_key = "api:#{endpoint}:#{Digest::MD5.hexdigest(params.to_s)}"
    Rails.cache.fetch(cache_key, expires_in: expires_in, &block)
  end
end

# Include helpers in controllers and models
ActionController::Base.include CacheHelpers if defined?(ActionController::Base)
ActiveRecord::Base.include CacheHelpers if defined?(ActiveRecord::Base)