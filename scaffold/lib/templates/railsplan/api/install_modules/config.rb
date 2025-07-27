# frozen_string_literal: true

# API module configuration installer

say_status :api_config, "Setting up API configuration"

# Create API configuration
initializer 'api.rb', <<~'RUBY'
  # API module configuration
  Rails.application.config.api = ActiveSupport::OrderedOptions.new
  
  # API versioning
  Rails.application.config.api.current_version = 'v1'
  Rails.application.config.api.supported_versions = ['v1']
  
  # Rate limiting
  Rails.application.config.api.rate_limit_requests = 1000
  Rails.application.config.api.rate_limit_window = 1.hour
  
  # Authentication
  Rails.application.config.api.require_authentication = true
  Rails.application.config.api.token_expiry = 24.hours
  
  # CORS configuration
  Rails.application.config.api.cors_origins = ['localhost:3000']
  Rails.application.config.api.cors_allowed_methods = %w[GET POST PUT PATCH DELETE OPTIONS]
RUBY

# Create Rswag configuration
initializer 'rswag_api.rb', <<~'RUBY'
  # Rswag API documentation configuration
  Rswag::Api.configure do |c|
    c.swagger_root = Rails.root.to_s + '/swagger'
    c.swagger_filter = lambda { |swagger, env| swagger }
  end
RUBY

initializer 'rswag_ui.rb', <<~'RUBY'
  # Rswag UI configuration
  Rswag::Ui.configure do |c|
    c.swagger_endpoint '/api-docs/v1/swagger.yaml', 'API V1 Docs'
    c.basic_auth_enabled = Rails.env.production?
    c.basic_auth_credentials 'admin', ENV.fetch('SWAGGER_PASSWORD', 'password')
  end
RUBY

say_status :api_config, "API configuration created"