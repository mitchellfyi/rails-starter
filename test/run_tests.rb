#!/usr/bin/env ruby
# frozen_string_literal: true

# Test runner for all Rails SaaS Starter Template tests

test_files = Dir.glob(File.expand_path('*_test.rb', __dir__))

puts "🧪 Running Rails SaaS Starter Template Test Suite..."
puts "   Found #{test_files.length} test files"
puts ""

passed = 0
failed = 0

test_files.each do |test_file|
  test_name = File.basename(test_file, '.rb')
  puts "Running #{test_name}..."
  
  result = system("ruby #{test_file}")
  
  if result
    passed += 1
    puts "✅ #{test_name} passed"
  else
    failed += 1
    puts "❌ #{test_name} failed"
  end
  
  puts ""
end

puts "Test Results:"
puts "  Passed: #{passed}"
puts "  Failed: #{failed}"
puts "  Total:  #{passed + failed}"

if failed > 0
  puts ""
  puts "❌ Some tests failed!"
  exit 1
else
  puts ""
  puts "✅ All tests passed!"
end