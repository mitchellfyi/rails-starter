# frozen_string_literal: true

# DemoFeature module initializer
# This file will be copied to config/initializers/demo_feature.rb during installation

Rails.application.configure do
  config.demo_feature = ActiveSupport::OrderedOptions.new
  
  # Module configuration options
  config.demo_feature.enabled = true
  config.demo_feature.items_per_page = 20
  config.demo_feature.allow_public_access = false
  
  # Add your custom configuration options here
  # config.demo_feature.custom_option = 'default_value'
end

# Optional: Add helpers or custom logic
# if defined?(ActionView::Base)
#   ActionView::Base.include DemoFeatureHelper
# end
