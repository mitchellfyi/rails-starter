# frozen_string_literal: true

# Configure secure headers when paranoid mode is enabled
if ParanoidMode.enabled?
  SecureHeaders::Configuration.default do |config|
    # Content Security Policy
    config.csp = {
      default_src: ParanoidMode.config.content_security_policy[:default_src],
      font_src: ParanoidMode.config.content_security_policy[:font_src],
      img_src: ParanoidMode.config.content_security_policy[:img_src],
      object_src: ParanoidMode.config.content_security_policy[:object_src],
      script_src: ParanoidMode.config.content_security_policy[:script_src],
      style_src: ParanoidMode.config.content_security_policy[:style_src],
      connect_src: ParanoidMode.config.content_security_policy[:connect_src],
      base_uri: ["'self'"],
      form_action: ["'self'"],
      frame_ancestors: ["'none'"],
      upgrade_insecure_requests: !Rails.env.development?
    }
    
    # HTTP Strict Transport Security
    if ParanoidMode.config.force_https
      config.hsts = {
        max_age: ParanoidMode.config.hsts_max_age,
        include_subdomains: ParanoidMode.config.hsts_include_subdomains,
        preload: ParanoidMode.config.hsts_preload
      }
    else
      config.hsts = SecureHeaders::OPT_OUT
    end
    
    # X-Frame-Options
    config.x_frame_options = 'DENY'
    
    # X-Content-Type-Options
    config.x_content_type_options = 'nosniff'
    
    # X-XSS-Protection (legacy browsers)
    config.x_xss_protection = '1; mode=block'
    
    # Referrer Policy
    config.referrer_policy = 'strict-origin-when-cross-origin'
    
    # Permissions Policy
    config.x_permitted_cross_domain_policies = 'none'
  end
  
  Rails.logger.info "Secure Headers: ENABLED with CSP and HSTS" if Rails.logger
else
  Rails.logger.info "Secure Headers: DISABLED (paranoid mode off)" if Rails.logger
end