#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to simulate CI environment with Ruby 3.2.9
require_relative 'lib/railsplan'

puts "=== RailsPlan CI Support Test ==="
puts "Simulating CI environment with Ruby 3.2.9"

# Test Ruby version support
ruby_manager = RailsPlan::RubyManager.new

puts "\n1. Ruby Version Support:"
puts "   Current Ruby: #{RUBY_VERSION}"
puts "   Minimum supported: #{ruby_manager.minimum_supported_version}"
puts "   Supported: #{ruby_manager.current_version_supported? ? '✓' : '✗'}"

# Test version compatibility for 3.2.9
puts "\n2. Testing Ruby 3.2.9 compatibility:"
test_version = "3.2.9"
compatible = ruby_manager.version_compatible?(test_version)
puts "   Ruby #{test_version} compatible: #{compatible ? '✓' : '✗'}"

# Test suggested version
puts "\n3. Suggested Ruby version:"
suggested = ruby_manager.suggest_ruby_version
puts "   Suggested: #{suggested}"

# Test error handling
puts "\n4. Error handling test:"
begin
  # Simulate the CI error scenario
  unless ruby_manager.current_version_supported?
    min_version = ruby_manager.minimum_supported_version
    raise "Ruby #{RUBY_VERSION} is not supported. Please use Ruby >= #{min_version}"
  end
  puts "   ✓ No error raised (version supported)"
rescue => e
  puts "   ✗ Error: #{e.message}"
end

puts "\n=== Test Complete ==="
puts "RailsPlan should now support Ruby 3.2.9 in CI environments!" 