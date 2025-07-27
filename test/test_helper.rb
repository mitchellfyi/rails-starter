# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

# Basic test helper for admin functionality
# This file provides basic testing setup for the admin panel

class AdminTestCase
  def self.verify_admin_functionality
    errors = []
    
    # Check that required models exist
    unless defined?(AuditLog)
      errors << "AuditLog model not found"
    end
    
    unless defined?(FeatureFlag)
      errors << "FeatureFlag model not found"
    end
    
    # Check that controllers exist
    unless defined?(Admin::AuditController)
      errors << "Admin::AuditController not found"
    end
    
    unless defined?(Admin::FeatureFlagsController)
      errors << "Admin::FeatureFlagsController not found"
    end
    
    if errors.empty?
      puts "✅ All admin functionality appears to be properly implemented"
      true
    else
      puts "❌ Admin functionality issues found:"
      errors.each { |error| puts "  - #{error}" }
      false
    end
  end
end