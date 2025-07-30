#!/usr/bin/env ruby
# frozen_string_literal: true

# Test the AI CLI commands work end-to-end
# This demonstrates the full user workflow

puts "🧪 RailsPlan AI Integration Test"
puts "================================="
puts ""

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

require "tmpdir"
require "fileutils"

def test_cli_commands
  # Create a temporary test app
  Dir.mktmpdir("railsplan_integration_test") do |test_dir|
    puts "📂 Test directory: #{test_dir}"
    
    # Create a mock Rails app
    Dir.chdir(test_dir) do
      puts "📁 Creating Rails app structure..."
      
      FileUtils.mkdir_p("app/models")
      FileUtils.mkdir_p("config")
      FileUtils.mkdir_p("db")
      
      File.write("Gemfile", "source 'https://rubygems.org'\ngem 'rails'")
      File.write("config/application.rb", "module TestApp\n  class Application < Rails::Application\n  end\nend")
      
      File.write("db/schema.rb", <<~SCHEMA)
        ActiveRecord::Schema.define(version: 2024_01_01_000000) do
          create_table "users", force: :cascade do |t|
            t.string "email"
            t.string "name"
            t.timestamps
          end
        end
      SCHEMA
      
      File.write("app/models/user.rb", <<~MODEL)
        class User < ApplicationRecord
          validates :email, presence: true, uniqueness: true
          has_many :posts, dependent: :destroy
        end
      MODEL
      
      puts "✅ Rails app structure created"
      
      # Test the railsplan CLI commands
      cli_path = File.expand_path("../bin/railsplan", __FILE__)
      
      puts ""
      puts "🧪 Testing railsplan CLI commands..."
      
      # Test the index command  
      puts "  → Testing 'railsplan index'..."
      system("ruby -I#{File.expand_path("../lib", __FILE__)} #{cli_path} index")
      
      if File.exist?(".railsplan/context.json")
        puts "  ✅ Index command created context file"
        context_size = File.size(".railsplan/context.json")
        puts "  📊 Context file size: #{context_size} bytes"
      else
        puts "  ❌ Index command failed to create context file"
      end
      
      # Test help for generate command
      puts ""
      puts "  → Testing 'railsplan generate --help'..."
      help_output = `ruby -I#{File.expand_path("../lib", __FILE__)} #{cli_path} help generate 2>&1`
      
      if help_output.include?("Generate Rails code using AI")
        puts "  ✅ Generate command help is available"
      else
        puts "  ❌ Generate command help failed"
        puts "  Output: #{help_output}"
      end
      
      # Test the version command
      puts ""
      puts "  → Testing 'railsplan version'..."
      version_output = `ruby -I#{File.expand_path("../lib", __FILE__)} #{cli_path} version 2>&1`
      
      if version_output.include?("RailsPlan")
        puts "  ✅ Version command works"
        puts "  📋 #{version_output.strip}"
      else
        puts "  ❌ Version command failed"
        puts "  Output: #{version_output}"
      end
      
      puts ""
      puts "🎉 CLI integration test completed!"
    end
  end
end

# Run the integration test
begin
  test_cli_commands
rescue => e
  puts "❌ Integration test failed: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
  exit 1
end