# frozen_string_literal: true

# Bullet gem configuration for N+1 query detection
# This helps identify performance issues during development

if defined?(Bullet)
  Bullet.enable = true
  
  # Enable N+1 query detection
  Bullet.bullet_logger = true
  Bullet.console = true
  
  # Enable unused eager loading detection
  Bullet.unused_eager_loading_enable = true
  
  # Show alerts in browser during development
  Bullet.alert = true if Rails.env.development?
  
  # Add bullet notifications to Rails logs
  Bullet.rails_logger = true
  
  # Raise errors in test environment to catch issues early
  Bullet.raise = true if Rails.env.test?
  
  # Skip checking for certain models that may have complex associations
  # Bullet.add_safelist type: :n_plus_one_query, class_name: 'ModelName', association: :association_name
  
  Rails.logger.info '🔫 Bullet gem configured for N+1 query detection'
end