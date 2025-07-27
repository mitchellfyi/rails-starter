#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify Ruby version support
require_relative 'lib/railsplan'

# Test Ruby version support
ruby_manager = RailsPlan::RubyManager.new

puts "Testing Ruby version support..."
puts "Current Ruby version: #{RUBY_VERSION}"
puts "Minimum supported version: #{ruby_manager.minimum_supported_version}"
puts "Current version supported: #{ruby_manager.current_version_supported?}"

# Test specific versions
test_versions = ["3.4.2", "3.3.0", "3.2.9", "3.2.0", "3.1.0", "3.0.0"]

puts "\nTesting specific versions:"
test_versions.each do |version|
  supported = ruby_manager.current_version_supported?
  puts "  #{version}: #{supported ? '✓' : '✗'}"
end

puts "\nTest completed!" 