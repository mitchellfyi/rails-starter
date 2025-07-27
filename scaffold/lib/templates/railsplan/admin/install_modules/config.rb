# frozen_string_literal: true

# Admin module configuration installer
# This modular installer handles configuration and initializers

say_status :admin_config, "Setting up admin configuration"

# Create admin configuration initializer
initializer 'admin.rb', <<~'RUBY'
  # Admin panel configuration
  Rails.application.config.admin = ActiveSupport::OrderedOptions.new
  
  # Session timeout for impersonation (in minutes)
  Rails.application.config.admin.impersonation_timeout = 60
  
  # Enable/disable audit logging
  Rails.application.config.admin.audit_enabled = true
  
  # Models to audit (add more as needed)
  Rails.application.config.admin.audited_models = %w[User]
RUBY

# Create Flipper configuration
initializer 'flipper.rb', <<~'RUBY'
  # Flipper feature flag configuration
  require 'flipper'
  require 'flipper/adapters/active_record'
  
  Flipper.configure do |config|
    config.adapter { Flipper::Adapters::ActiveRecord.new }
  end
  
  # Auto-register feature flags
  Rails.application.config.to_prepare do
    # Core feature flags
    Flipper.add(:admin_panel)
    Flipper.add(:user_impersonation)
    Flipper.add(:audit_logging)
    Flipper.add(:sidekiq_ui)
  end
RUBY

# Create Pundit configuration
initializer 'pundit.rb', <<~'RUBY'
  # Pundit authorization configuration
  Pundit.configure do |config|
    config.default_policy_class = "ApplicationPolicy"
    config.policy_class_name = lambda { |record| "#{record.class}Policy" }
  end
RUBY

say_status :admin_config, "Admin configuration created"