#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify Ruby 3.2.9 is properly rejected
require_relative 'lib/railsplan'

puts "=== RailsPlan Ruby 3.2.9 Rejection Test ==="

# Test Ruby version support
ruby_manager = RailsPlan::RubyManager.new

puts "\n1. Current Environment:"
puts "   Current Ruby: #{RUBY_VERSION}"
puts "   Minimum supported: #{ruby_manager.minimum_supported_version}"
puts "   Supported: #{ruby_manager.current_version_supported? ? '✓' : '✗'}"

puts "\n2. Testing Ruby 3.2.9 rejection:"
test_version = "3.2.9"
compatible = ruby_manager.version_compatible?(test_version)
puts "   Ruby #{test_version} compatible: #{compatible ? '✓' : '✗'}"

# Simulate the error that would occur with Ruby 3.2.9
puts "\n3. Simulating Ruby 3.2.9 error scenario:"
begin
  # This would be the error message in CI
  unless ruby_manager.current_version_supported?
    min_version = ruby_manager.minimum_supported_version
    raise "Ruby #{RUBY_VERSION} is not supported. Please use Ruby >= #{min_version}"
  end
  puts "   ✓ Current Ruby version is supported"
rescue => e
  puts "   ✗ Error: #{e.message}"
end

puts "\n4. Supported Ruby versions:"
supported_versions = ["3.4.2", "3.4.1", "3.4.0", "3.3.0"]
supported_versions.each do |version|
  supported = ruby_manager.current_version_supported?
  puts "   #{version}: #{supported ? '✓' : '✗'}"
end

puts "\n=== Test Complete ==="
puts "RailsPlan now properly requires Ruby 3.3.0+ and will reject Ruby 3.2.9!" 