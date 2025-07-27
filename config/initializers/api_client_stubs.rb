# frozen_string_literal: true

# Auto-load API client factory for test environment
if Rails.env.test?
  require Rails.root.join('lib', 'api_client_factory')
end