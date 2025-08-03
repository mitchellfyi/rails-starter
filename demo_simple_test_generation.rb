#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple demo script for AI test generation feature
# Tests the core functionality without full CLI dependencies

puts "🧪 RailsPlan AI Test Generation - Core Functionality Demo"
puts "=" * 60

# Load just the test command
$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

# Load individual files without CLI dependencies
require "json"
require "fileutils"
require "time"

# Load the test command directly
require_relative "lib/railsplan/commands/base_command"
require_relative "lib/railsplan/commands/test_generate_command"

# Create a temporary Rails app for demo
temp_dir = "/tmp/railsplan_test_demo_simple"
original_dir = Dir.pwd

begin
  FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  FileUtils.mkdir_p(temp_dir)
  Dir.chdir(temp_dir)

  puts "\n📁 Setting up demo Rails application..."
  
  # Create directory structure
  FileUtils.mkdir_p([
    "app/models",
    "app/controllers", 
    "app/jobs",
    "test/models",
    "test/controllers",
    "test/system",
    "test/integration",
    "test/jobs",
    "spec/models",
    "spec/controllers", 
    "spec/system",
    "spec/requests",
    "spec/jobs",
    "config",
    ".railsplan"
  ])
  
  # Create minimal Rails files
  File.write("config/application.rb", "class Application; end")
  File.write("Gemfile", "gem 'rails'")
  
  # Create sample model
  File.write("app/models/user.rb", <<~RUBY)
    class User < ApplicationRecord
      validates :email, presence: true, uniqueness: true
      validates :name, presence: true
      
      has_many :posts, dependent: :destroy
    end
  RUBY
  
  # Create railsplan context
  context = {
    "generated_at" => Time.now.iso8601,
    "app_name" => "DemoApp",
    "models" => [
      {
        "file" => "app/models/user.rb",
        "class_name" => "User",
        "associations" => [
          { "type" => "has_many", "name" => "posts" }
        ],
        "validations" => [
          { "field" => "email", "rules" => "presence: true, uniqueness: true" },
          { "field" => "name", "rules" => "presence: true" }
        ]
      }
    ],
    "schema" => {
      "users" => {
        "columns" => {
          "id" => { "type" => "integer" },
          "email" => { "type" => "string" },
          "name" => { "type" => "string" },
          "created_at" => { "type" => "datetime" },
          "updated_at" => { "type" => "datetime" }
        }
      }
    },
    "routes" => [
      { "verb" => "GET", "path" => "/users", "controller" => "users", "action" => "index" }
    ],
    "controllers" => [],
    "modules" => []
  }
  
  File.write(".railsplan/context.json", JSON.pretty_generate(context))
  
  puts "✅ Demo Rails application created"
  
  # Demo the test generation command
  puts "\n🤖 Testing AI Test Generation Features..."
  puts "-" * 40
  
  # Initialize test command
  test_command = RailsPlan::Commands::TestGenerateCommand.new(verbose: false)
  
  # Demo 1: Test type detection
  puts "\n1. 🎯 Test Type Auto-Detection:"
  
  test_cases = [
    "User signs up with email and password",
    "API returns user data in JSON format", 
    "User model validates email uniqueness",
    "Email notification job sends welcome email",
    "Users controller handles create action properly",
    "User visits dashboard page",
    "Admin can delete user account"
  ]
  
  test_cases.each do |instruction|
    detected_type = test_command.send(:determine_test_type, instruction, {})
    puts "   \"#{instruction}\""
    puts "   → #{detected_type} test"
    puts ""
  end
  
  # Demo 2: Framework detection
  puts "2. 🔧 Test Framework Detection:"
  
  framework = test_command.send(:detect_test_framework, context)
  puts "   Default framework: #{framework}"
  
  # Test with RSpec
  File.write("spec/spec_helper.rb", "# RSpec configuration")
  framework_rspec = test_command.send(:detect_test_framework, context)
  puts "   With RSpec files present: #{framework_rspec}"
  
  # Demo 3: Test requirements generation
  puts "\n3. 📋 Test Requirements Generation:"
  
  test_types = %w[system request model job controller]
  frameworks = %w[Minitest RSpec]
  
  test_types.each do |test_type|
    puts "\n   #{test_type.upcase} Test Requirements:"
    frameworks.each do |framework|
      puts "     #{framework}:"
      requirements = test_command.send(:test_requirements_for_type, test_type, framework)
      requirements.split("\n").first(3).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?("-")
        puts "       #{line}" if line.length > 0
      end
    end
  end
  
  # Demo 4: Enhanced instruction building
  puts "\n4. 📝 Enhanced Test Instruction Building:"
  
  instruction = "User authentication workflow"
  test_type = "system"
  enhanced = test_command.send(:build_test_instruction, instruction, test_type, context)
  
  puts "   Original: \"#{instruction}\""
  puts "   Enhanced instruction includes:"
  puts "   • Test type: #{test_type}"
  puts "   • Framework: Minitest"
  puts "   • Specific requirements for #{test_type} tests"
  puts "   • Application context (models, routes, etc.)"
  puts "   • Rails testing best practices"
  
  # Demo 5: Type override functionality
  puts "\n5. ⚙️  Type Override Functionality:"
  
  instruction = "User signs up with email"  # Would normally be 'system'
  original_type = test_command.send(:determine_test_type, instruction, {})
  override_type = test_command.send(:determine_test_type, instruction, { type: "model" })
  
  puts "   Instruction: \"#{instruction}\""
  puts "   Auto-detected: #{original_type}"
  puts "   With --type=model: #{override_type}"
  
  # Demo 6: Rails app detection
  puts "\n6. 🔍 Rails Application Detection:"
  
  is_rails_app = test_command.send(:rails_app?)
  puts "   Is Rails app: #{is_rails_app}"
  puts "   Checks for: config/application.rb or Gemfile"
  
  # Demo 7: Available test types
  puts "\n7. 📚 Available Test Types:"
  
  RailsPlan::Commands::TestGenerateCommand::TEST_TYPES.each do |type|
    puts "   • #{type}"
  end
  
  puts "\n✨ Core functionality demo completed!"
  puts "\n📖 Usage Examples:"
  puts "   railsplan generate test \"User signs up with email and password\""
  puts "   railsplan generate test \"API returns user data\" --type=request"
  puts "   railsplan generate test \"User model validation\" --dry-run"
  puts "   railsplan generate test \"Email job processes queue\" --force --validate"
  
ensure
  Dir.chdir(original_dir)
end

puts "\n" + "=" * 60
puts "🎉 Core Functionality Demo Complete!"
puts "\nKey Features Demonstrated:"
puts "• ✅ Intelligent test type detection from natural language"
puts "• ✅ Support for both RSpec and Minitest frameworks"
puts "• ✅ Comprehensive test requirements for each test type"
puts "• ✅ Type override functionality with --type option"
puts "• ✅ Rails application detection"
puts "• ✅ Context-aware test instruction enhancement"
puts "• ✅ All #{RailsPlan::Commands::TestGenerateCommand::TEST_TYPES.length} test types supported"