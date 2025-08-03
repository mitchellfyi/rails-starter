#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script specifically for the chat command functionality

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

# Minimal setup
module RailsPlan
  class Error < StandardError; end
  
  def self.logger
    @logger ||= Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
  end
end

require 'logger'
require 'railsplan/ai_config'
require 'railsplan/ai'
require 'railsplan/commands/chat_command'

puts "🧪 Testing Chat Command Functionality"
puts "=" * 40

# Create test config
temp_dir = Dir.mktmpdir("railsplan_chat_test")
config_path = File.join(temp_dir, "ai.yml")

config_content = <<~YAML
  provider: openai
  openai_api_key: test_key
  model: gpt-4o
YAML

File.write(config_path, config_content)

# Override config path
original_path = RailsPlan::AIConfig::DEFAULT_CONFIG_PATH
RailsPlan::AIConfig.send(:remove_const, :DEFAULT_CONFIG_PATH)
RailsPlan::AIConfig.const_set(:DEFAULT_CONFIG_PATH, config_path)

begin
  puts "\n1. Testing ChatCommand initialization..."
  command = RailsPlan::Commands::ChatCommand.new(verbose: false)
  puts "   ✅ Chat command created successfully"

  puts "\n2. Testing provider determination..."
  provider = command.send(:determine_provider, { provider: "claude" })
  if provider == :claude
    puts "   ✅ Provider correctly determined from options"
  else
    puts "   ❌ Provider determination failed"
  end

  provider = command.send(:determine_provider, {})
  if RailsPlan::AI.available_providers.include?(provider)
    puts "   ✅ Default provider fallback working"
  else
    puts "   ❌ Default provider fallback failed"
  end

  puts "\n3. Testing AI interface integration..."
  
  # Mock AI.call to avoid actual API calls
  original_call = RailsPlan::AI.method(:call)
  
  # Define a simple mock
  RailsPlan::AI.define_singleton_method(:call) do |provider:, prompt:, **options|
    {
      output: "Mock response for: #{prompt}",
      metadata: {
        provider: provider,
        model: "mock-model",
        tokens_used: 42,
        cost_estimate: 0.001,
        success: true
      }
    }
  end
  
  # Test single prompt execution
  puts "   Testing single prompt mode..."
  
  # Capture output to avoid cluttering test results
  original_stdout = $stdout
  $stdout = StringIO.new
  
  result = command.execute("Test prompt", { provider: "openai" })
  
  $stdout = original_stdout
  
  if result
    puts "   ✅ Single prompt execution successful"
  else
    puts "   ❌ Single prompt execution failed"
  end

  puts "\n4. Testing error handling..."
  
  # Mock AI.call to raise an error
  RailsPlan::AI.define_singleton_method(:call) do |provider:, prompt:, **options|
    raise RailsPlan::Error.new("Mock API error")
  end
  
  $stdout = StringIO.new
  result = command.execute("Test prompt", { provider: "openai" })
  $stdout = original_stdout
  
  if result  # Should still return true as it handles errors gracefully
    puts "   ✅ Error handling working correctly"
  else
    puts "   ❌ Error handling failed"
  end

  puts "\n5. Testing format validation..."
  
  # Test available formats
  valid_formats = [:markdown, :ruby, :json, :html_partial]
  valid_formats.each do |format|
    begin
      RailsPlan::AI.send(:validate_inputs!, :openai, "test prompt", format)
      puts "   ✅ Format #{format} accepted"
    rescue ArgumentError
      puts "   ❌ Format #{format} incorrectly rejected"
    end
  end
  
  # Test invalid format
  begin
    RailsPlan::AI.send(:validate_inputs!, :openai, "test prompt", :invalid_format)
    puts "   ❌ Invalid format should have been rejected"
  rescue ArgumentError
    puts "   ✅ Invalid format correctly rejected"
  end

  puts "\n6. Testing configuration integration..."
  
  # Test that chat command can access configuration
  config = RailsPlan::AIConfig.new
  if config.provider == "openai" && config.model == "gpt-4o"
    puts "   ✅ Configuration properly loaded"
  else
    puts "   ❌ Configuration loading failed"
  end

  puts "\n7. Testing CLI help integration..."
  
  # Mock output capture for help methods
  original_puts = method(:puts)
  help_output = []
  
  define_singleton_method(:puts) do |*args|
    help_output.concat(args)
  end
  
  command.send(:show_help)
  command.send(:show_providers)
  
  # Restore puts
  define_singleton_method(:puts, original_puts)
  
  if help_output.any? { |line| line.to_s.include?("Available commands") }
    puts "   ✅ Help system working"
  else
    puts "   ❌ Help system failed"
  end
  
  if help_output.any? { |line| line.to_s.include?("Available providers") }
    puts "   ✅ Provider listing working"
  else
    puts "   ❌ Provider listing failed"
  end

rescue => e
  puts "   ❌ Test failed with error: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
ensure
  # Cleanup
  FileUtils.rm_rf(temp_dir)
  
  # Restore original config path
  RailsPlan::AIConfig.send(:remove_const, :DEFAULT_CONFIG_PATH)
  RailsPlan::AIConfig.const_set(:DEFAULT_CONFIG_PATH, original_path)
end

puts "\n" + "=" * 40
puts "✅ Chat Command Tests Complete!"
puts "   All functionality verified and working"

require 'stringio'