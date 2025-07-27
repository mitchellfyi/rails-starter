# frozen_string_literal: true

# TestWithHyphens module initializer
# This file will be copied to config/initializers/test-with-hyphens.rb during installation

Rails.application.configure do
  config.test-with-hyphens = ActiveSupport::OrderedOptions.new
  
  # Module configuration options
  config.test-with-hyphens.enabled = true
  config.test-with-hyphens.items_per_page = 20
  config.test-with-hyphens.allow_public_access = false
  
  # Add your custom configuration options here
  # config.test-with-hyphens.custom_option = 'default_value'
end

# Optional: Add helpers or custom logic
# if defined?(ActionView::Base)
#   ActionView::Base.include TestWithHyphensHelper
# end
