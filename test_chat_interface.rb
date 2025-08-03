#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual test for schema-aware chat interface
puts "Testing RailsPlan Chat Interface..."

# Test 1: Check if DataPreview service loads
begin
  require_relative 'lib/railsplan/data_preview'
  puts "✅ DataPreview service loads successfully"
rescue => e
  puts "❌ DataPreview service failed to load: #{e.message}"
  exit 1
end

# Test 2: Check if DataPreview validates queries safely
begin
  preview = RailsPlan::DataPreview.new
  
  # Test safe query
  preview.send(:validate_sql_safety!, "SELECT * FROM users LIMIT 10")
  puts "✅ Safe SQL validation works"
  
  # Test unsafe query
  begin
    preview.send(:validate_sql_safety!, "DROP TABLE users")
    puts "❌ Unsafe SQL validation failed - should have raised error"
    exit 1
  rescue RailsPlan::DataPreview::UnsafeQueryError
    puts "✅ Unsafe SQL correctly rejected"
  end
  
rescue => e
  puts "❌ DataPreview validation failed: #{e.message}"
  exit 1
end

# Test 3: Check if enhanced ContextManager loads
begin
  require_relative 'lib/railsplan/context_manager'
  puts "✅ Enhanced ContextManager loads successfully"
rescue => e
  puts "❌ Enhanced ContextManager failed to load: #{e.message}"
  exit 1
end

# Test 4: Check if controller file is syntactically correct
begin
  # Just check syntax, don't load (since it depends on Rails)
  system("ruby -c app/controllers/railsplan_chat_controller.rb > /dev/null 2>&1")
  if $?.success?
    puts "✅ RailsplanChatController syntax is correct"
  else
    puts "❌ RailsplanChatController has syntax errors"
    exit 1
  end
rescue => e
  puts "❌ Failed to check RailsplanChatController: #{e.message}"
  exit 1
end

puts ""
puts "🎉 All tests passed! Schema-aware chat interface is ready."
puts ""
puts "Next steps:"
puts "1. Start Rails server: bin/rails server"
puts "2. Visit http://localhost:3000/railsplan/chat"
puts "3. Test the chat interface with schema-aware questions"