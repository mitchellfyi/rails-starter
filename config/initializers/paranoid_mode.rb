# frozen_string_literal: true

# Paranoid Mode Configuration
# Enable enhanced security features for production environments
# Set PARANOID_MODE=true in your environment to enable

module ParanoidMode
  class Configuration
    include ActiveSupport::Configurable
    
    # Security features
    config_accessor :enabled, default: false
    config_accessor :force_https, default: true
    config_accessor :secure_headers, default: true
    config_accessor :session_timeout, default: 30.minutes
    config_accessor :admin_2fa_required, default: true
    config_accessor :encrypt_sensitive_attributes, default: true
    
    # CSP Configuration
    config_accessor :content_security_policy, default: {
      default_src: ["'self'"],
      font_src: ["'self'", 'data:', 'https:'],
      img_src: ["'self'", 'data:', 'https:'],
      object_src: ["'none'"],
      script_src: ["'self'"],
      style_src: ["'self'", "'unsafe-inline'"],
      connect_src: ["'self'"]
    }
    
    # HSTS Configuration
    config_accessor :hsts_max_age, default: 31_536_000 # 1 year
    config_accessor :hsts_include_subdomains, default: true
    config_accessor :hsts_preload, default: true
    
    def self.enabled?
      config.enabled || ENV['PARANOID_MODE'].present?
    end
    
    def self.development_mode?
      Rails.env.development?
    end
    
    def self.test_mode?
      Rails.env.test?
    end
  end
  
  # Global configuration instance
  def self.config
    @config ||= Configuration.new
  end
  
  def self.configure
    yield(config)
  end
  
  def self.enabled?
    config.enabled || ENV['PARANOID_MODE'].present?
  end
end

# Auto-enable paranoid mode based on environment variable
ParanoidMode.configure do |config|
  config.enabled = ENV['PARANOID_MODE'].present?
  
  # Adjust settings for development
  if Rails.env.development?
    config.force_https = false unless ENV['PARANOID_FORCE_HTTPS'].present?
    config.session_timeout = 1.hour
  end
  
  # Adjust settings for test
  if Rails.env.test?
    config.enabled = ENV['PARANOID_MODE_TEST'].present?
    config.force_https = false
    config.session_timeout = 10.minutes
  end
end

Rails.logger.info "Paranoid Mode: #{ParanoidMode.enabled? ? 'ENABLED' : 'DISABLED'}" if Rails.logger