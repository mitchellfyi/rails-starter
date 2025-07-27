# frozen_string_literal: true

# Session security configuration for paranoid mode
if ParanoidMode.enabled?
  Rails.application.config.session_store :cookie_store,
    key: "_rails_starter_session",
    httponly: true,
    secure: ParanoidMode.config.force_https,
    same_site: :strict,
    expire_after: ParanoidMode.config.session_timeout
    
  # Configure session security middleware
  Rails.application.config.force_ssl = true if ParanoidMode.config.force_https && Rails.env.production?
  
  Rails.logger.info "Session Security: ENABLED with #{ParanoidMode.config.session_timeout} timeout" if Rails.logger
else
  Rails.application.config.session_store :cookie_store,
    key: "_rails_starter_session",
    httponly: true,
    secure: Rails.env.production?,
    same_site: :lax
    
  Rails.logger.info "Session Security: STANDARD (paranoid mode off)" if Rails.logger
end