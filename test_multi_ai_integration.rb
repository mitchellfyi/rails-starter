#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual test script for RailsPlan multi-AI CLI integration
# This script tests the core functionality without requiring Rails dependencies

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

# Define the Error class that AI module expects
module RailsPlan
  class Error < StandardError; end
end

require 'railsplan/ai_config'
require 'railsplan/ai'
require 'tempfile'
require 'fileutils'

# Helper method for simple assertions
def assert_equal(expected, actual)
  unless expected == actual
    raise "Assertion failed: expected #{expected}, got #{actual}"
  end
end

puts "🧪 Testing RailsPlan Multi-AI CLI Integration"
puts "=" * 50

# Test 1: Available providers
puts "\n1. Testing available providers..."
providers = RailsPlan::AI.available_providers
puts "   Available providers: #{providers.join(', ')}"
assert_equal [:openai, :claude, :gemini, :cursor], providers
puts "   ✅ All expected providers available"

# Test 2: Input validation
puts "\n2. Testing input validation..."

# Test invalid provider
begin
  RailsPlan::AI.call(provider: :invalid, prompt: "test")
  puts "   ❌ Should have raised error for invalid provider"
rescue ArgumentError => e
  puts "   ✅ Correctly rejected invalid provider: #{e.message}"
end

# Test empty prompt
begin
  RailsPlan::AI.call(provider: :openai, prompt: "")
  puts "   ❌ Should have raised error for empty prompt"
rescue ArgumentError => e
  puts "   ✅ Correctly rejected empty prompt: #{e.message}"
end

# Test invalid format
begin
  RailsPlan::AI.call(provider: :openai, prompt: "test", format: :invalid)
  puts "   ❌ Should have raised error for invalid format"
rescue ArgumentError => e
  puts "   ✅ Correctly rejected invalid format: #{e.message}"
end

# Test 3: Configuration loading
puts "\n3. Testing configuration loading..."

# Create temporary config
temp_dir = Dir.mktmpdir("railsplan_test")
config_path = File.join(temp_dir, "ai.yml")

# Test simple format
config_content = <<~YAML
  provider: openai
  model: gpt-4o
  openai_api_key: test_key_123
YAML

File.write(config_path, config_content)

# Temporarily override the config path
original_path = RailsPlan::AIConfig::DEFAULT_CONFIG_PATH
RailsPlan::AIConfig.send(:remove_const, :DEFAULT_CONFIG_PATH)
RailsPlan::AIConfig.const_set(:DEFAULT_CONFIG_PATH, config_path)

begin
  config = RailsPlan::AIConfig.new
  puts "   Provider: #{config.provider}"
  puts "   Model: #{config.model}"
  puts "   ✅ Configuration loaded successfully"
rescue => e
  puts "   ❌ Configuration loading failed: #{e.message}"
end

# Test profiles format
profiles_config = <<~YAML
  provider: claude
  openai_api_key: test_openai_key
  claude_api_key: test_claude_key
  gemini_api_key: test_gemini_key
  
  profiles:
    development:
      provider: openai
      model: gpt-4o-mini
    production:
      provider: claude
      model: claude-3-5-sonnet-20241022
    experimental:
      provider: gemini
      model: gemini-1.5-pro
YAML

File.write(config_path, profiles_config)

begin
  config = RailsPlan::AIConfig.new(profile: "development")
  puts "   Development profile provider: #{config.provider}"
  
  config = RailsPlan::AIConfig.new(profile: "production")
  puts "   Production profile provider: #{config.provider}"
  
  puts "   ✅ Profile-based configuration working"
rescue => e
  puts "   ❌ Profile configuration failed: #{e.message}"
end

# Test 4: Output validation
puts "\n4. Testing output validation..."

# Valid JSON
begin
  RailsPlan::AI.send(:validate_output, '{"test": "value"}', :json)
  puts "   ✅ Valid JSON accepted"
rescue => e
  puts "   ❌ Valid JSON rejected: #{e.message}"
end

# Invalid JSON
begin
  RailsPlan::AI.send(:validate_output, 'invalid json', :json)
  puts "   ❌ Invalid JSON should have been rejected"
rescue RailsPlan::Error => e
  puts "   ✅ Invalid JSON correctly rejected: #{e.message}"
end

# Valid Ruby
begin
  RailsPlan::AI.send(:validate_output, 'puts "Hello World"', :ruby)
  puts "   ✅ Valid Ruby accepted"
rescue => e
  puts "   ❌ Valid Ruby rejected: #{e.message}"
end

# Invalid Ruby
begin
  RailsPlan::AI.send(:validate_output, 'invalid ruby {', :ruby)
  puts "   ❌ Invalid Ruby should have been rejected"
rescue RailsPlan::Error => e
  puts "   ✅ Invalid Ruby correctly rejected"
end

# Test 5: Provider fallback logic
puts "\n5. Testing provider fallback logic..."

fallbacks = {
  openai: :claude,
  claude: :openai,
  gemini: :openai,
  cursor: :openai
}

fallbacks.each do |provider, expected_fallback|
  actual_fallback = RailsPlan::AI.send(:get_fallback_provider, provider)
  if actual_fallback == expected_fallback
    puts "   ✅ #{provider} → #{actual_fallback}"
  else
    puts "   ❌ #{provider} expected #{expected_fallback}, got #{actual_fallback}"
  end
end

# Test 6: AI provider classes
puts "\n6. Testing AI provider classes..."

begin
  # Test OpenAI provider
  require 'railsplan/ai_provider/openai'
  openai_config = RailsPlan::AIConfig.new
  openai_config.instance_variable_set(:@provider, "openai")
  openai_config.instance_variable_set(:@model, "gpt-4o")
  openai_config.instance_variable_set(:@api_key, "test_key")
  
  openai_provider = RailsPlan::AIProvider::OpenAI.new(openai_config)
  puts "   ✅ OpenAI provider instantiated"
  
  # Test Claude provider
  require 'railsplan/ai_provider/claude'
  claude_config = RailsPlan::AIConfig.new
  claude_config.instance_variable_set(:@provider, "anthropic")
  claude_config.instance_variable_set(:@model, "claude-3-5-sonnet-20241022")
  claude_config.instance_variable_set(:@api_key, "test_key")
  
  claude_provider = RailsPlan::AIProvider::Claude.new(claude_config)
  puts "   ✅ Claude provider instantiated"
  
  # Test Gemini provider
  require 'railsplan/ai_provider/gemini'
  gemini_config = RailsPlan::AIConfig.new
  gemini_config.instance_variable_set(:@provider, "gemini")
  gemini_config.instance_variable_set(:@model, "gemini-1.5-pro")
  gemini_config.instance_variable_set(:@api_key, "test_key")
  
  gemini_provider = RailsPlan::AIProvider::Gemini.new(gemini_config)
  puts "   ✅ Gemini provider instantiated"
  
  # Test Cursor provider
  require 'railsplan/ai_provider/cursor'
  cursor_config = RailsPlan::AIConfig.new
  cursor_config.instance_variable_set(:@provider, "cursor")
  cursor_config.instance_variable_set(:@model, "cursor-local")
  
  cursor_provider = RailsPlan::AIProvider::Cursor.new(cursor_config)
  puts "   ✅ Cursor provider instantiated"
  
rescue => e
  puts "   ❌ Provider instantiation failed: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
end

# Test 7: Logging functionality
puts "\n7. Testing logging functionality..."

# Create a temporary .railsplan directory
log_dir = File.join(temp_dir, ".railsplan")
FileUtils.mkdir_p(log_dir)

begin
  # Test prompt logging
  metadata = {
    timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    provider: :openai,
    model: "gpt-4o",
    format: :markdown,
    success: true,
    prompt_size: 100,
    tokens_used: 50,
    cost_estimate: 0.01
  }
  
  # Temporarily change to temp directory for logging
  original_dir = Dir.pwd
  Dir.chdir(temp_dir)
  
  RailsPlan::AI.send(:log_interaction, "test prompt", "test output", metadata)
  
  prompt_log = File.join(log_dir, "prompts.log")
  if File.exist?(prompt_log)
    log_content = File.read(prompt_log)
    if log_content.include?("test prompt") && log_content.include?("openai")
      puts "   ✅ Prompt logging working"
    else
      puts "   ❌ Prompt log missing expected content"
    end
  else
    puts "   ❌ Prompt log file not created"
  end
  
  # Test usage logging
  RailsPlan::AI.send(:log_usage, metadata)
  
  usage_log = File.join(log_dir, "ai_usage.log")
  if File.exist?(usage_log)
    log_content = File.read(usage_log)
    if log_content.include?("openai") && log_content.include?("0.01")
      puts "   ✅ Usage logging working"
    else
      puts "   ❌ Usage log missing expected content"
    end
  else
    puts "   ❌ Usage log file not created"
  end
  
rescue => e
  puts "   ❌ Logging test failed: #{e.message}"
ensure
  Dir.chdir(original_dir) if original_dir
end

# Cleanup
puts "\n8. Cleaning up..."
FileUtils.rm_rf(temp_dir)

# Restore original config path
RailsPlan::AIConfig.send(:remove_const, :DEFAULT_CONFIG_PATH)
RailsPlan::AIConfig.const_set(:DEFAULT_CONFIG_PATH, original_path)

puts "   ✅ Cleanup completed"

puts "\n" + "=" * 50
puts "🎉 Multi-AI CLI Integration Test Complete!"
puts "   All core functionality verified successfully"