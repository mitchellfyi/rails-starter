# frozen_string_literal: true

# TestFeature module initializer
# This file will be copied to config/initializers/test_feature.rb during installation

Rails.application.configure do
  config.test_feature = ActiveSupport::OrderedOptions.new
  
  # Module configuration options
  config.test_feature.enabled = true
  config.test_feature.items_per_page = 20
  config.test_feature.allow_public_access = false
  
  # Add your custom configuration options here
  # config.test_feature.custom_option = 'default_value'
end

# Optional: Add helpers or custom logic
# if defined?(ActionView::Base)
#   ActionView::Base.include TestFeatureHelper
# end
