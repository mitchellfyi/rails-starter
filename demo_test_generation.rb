#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script for AI test generation feature
# This demonstrates the new railsplan generate test functionality

puts "🧪 RailsPlan AI Test Generation Demo"
puts "=" * 50

# Load the railsplan library
$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "railsplan"

# Create a temporary Rails app for demo
temp_dir = "/tmp/railsplan_test_demo"
FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
FileUtils.mkdir_p(temp_dir)

# Set up basic Rails structure
puts "\n📁 Setting up demo Rails application..."
Dir.chdir(temp_dir) do
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
  File.write("config/application.rb", <<~RUBY)
    require_relative 'boot'
    require 'rails/all'
    
    module DemoApp
      class Application < Rails::Application
        config.load_defaults 7.0
      end
    end
  RUBY
  
  File.write("Gemfile", <<~RUBY)
    source 'https://rubygems.org'
    gem 'rails', '~> 7.0'
    gem 'sqlite3'
  RUBY
  
  # Create sample models and controllers
  File.write("app/models/user.rb", <<~RUBY)
    class User < ApplicationRecord
      validates :email, presence: true, uniqueness: true
      validates :name, presence: true
      
      has_many :posts, dependent: :destroy
    end
  RUBY
  
  File.write("app/controllers/users_controller.rb", <<~RUBY)
    class UsersController < ApplicationController
      def index
        @users = User.all
      end
      
      def show
        @user = User.find(params[:id])
      end
      
      def create
        @user = User.new(user_params)
        if @user.save
          redirect_to @user, notice: 'User was successfully created.'
        else
          render :new
        end
      end
      
      private
      
      def user_params
        params.require(:user).permit(:name, :email)
      end
    end
  RUBY
  
  File.write("app/jobs/email_notification_job.rb", <<~RUBY)
    class EmailNotificationJob < ApplicationJob
      queue_as :default
      
      def perform(user_id, notification_type)
        user = User.find(user_id)
        NotificationMailer.send(notification_type, user).deliver_now
      end
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
      { "verb" => "GET", "path" => "/users", "controller" => "users", "action" => "index" },
      { "verb" => "POST", "path" => "/users", "controller" => "users", "action" => "create" },
      { "verb" => "GET", "path" => "/users/:id", "controller" => "users", "action" => "show" }
    ],
    "controllers" => [
      {
        "file" => "app/controllers/users_controller.rb",
        "class_name" => "UsersController",
        "actions" => ["index", "show", "create"]
      }
    ],
    "modules" => []
  }
  
  File.write(".railsplan/context.json", JSON.pretty_generate(context))
  
  puts "✅ Demo Rails application created at #{temp_dir}"
  
  # Demo the test generation command
  puts "\n🤖 Demonstrating AI Test Generation Features..."
  puts "-" * 50
  
  # Initialize test command
  test_command = RailsPlan::Commands::TestGenerateCommand.new(verbose: true)
  
  # Demo 1: Test type detection
  puts "\n1. 🎯 Test Type Auto-Detection:"
  
  test_cases = [
    "User signs up with email and password",
    "API returns user data in JSON format", 
    "User model validates email uniqueness",
    "Email notification job sends welcome email",
    "Users controller handles create action properly"
  ]
  
  test_cases.each do |instruction|
    detected_type = test_command.send(:determine_test_type, instruction, {})
    puts "   \"#{instruction}\" → #{detected_type} test"
  end
  
  # Demo 2: Framework detection
  puts "\n2. 🔧 Test Framework Detection:"
  
  framework = test_command.send(:detect_test_framework, context)
  puts "   Detected framework: #{framework}"
  
  # Test with RSpec
  File.write("spec/spec_helper.rb", "# RSpec configuration")
  framework_rspec = test_command.send(:detect_test_framework, context)
  puts "   With RSpec files: #{framework_rspec}"
  
  # Demo 3: Test requirements generation
  puts "\n3. 📋 Test Requirements Generation:"
  
  %w[system request model job].each do |test_type|
    puts "\n   #{test_type.upcase} Test Requirements (Minitest):"
    requirements = test_command.send(:test_requirements_for_type, test_type, "Minitest")
    requirements.split("\n").each { |line| puts "     #{line.strip}" if line.strip.length > 0 }
  end
  
  # Demo 4: Enhanced instruction building
  puts "\n4. 📝 Enhanced Test Instruction Building:"
  
  instruction = "User authentication workflow"
  test_type = "system"
  enhanced = test_command.send(:build_test_instruction, instruction, test_type, context)
  
  puts "   Original: \"#{instruction}\""
  puts "   Enhanced instruction preview:"
  enhanced.split("\n").first(5).each { |line| puts "     #{line}" }
  puts "     ... (additional context and requirements included)"
  
  # Demo 5: CLI command examples
  puts "\n5. 💻 CLI Command Examples:"
  puts "   railsplan generate test \"User signs up with email and password\""
  puts "   railsplan generate test \"API returns user data\" --type=request"
  puts "   railsplan generate test \"User model validation\" --dry-run"
  puts "   railsplan generate test \"Email job processes queue\" --force --validate"
  
  # Demo 6: Doctor integration
  puts "\n6. 🏥 Doctor Command Integration:"
  puts "   Missing test detection and auto-fix capability:"
  puts "   - Scans for models/controllers without tests"
  puts "   - Can auto-generate tests with AI when --fix is used"
  puts "   - Example: railsplan doctor --fix"
  
  puts "\n✨ Demo completed!"
  puts "📁 Demo files created in: #{temp_dir}"
  puts "\n🚀 To try the actual commands:"
  puts "   cd #{temp_dir}"
  puts "   railsplan generate test \"User signs up with email\" --dry-run"
  puts "   (Note: Requires AI provider configuration)"
  
end

puts "\n" + "=" * 50
puts "🎉 RailsPlan AI Test Generation Demo Complete!"
puts "\nKey Features Demonstrated:"
puts "• Intelligent test type detection from natural language"
puts "• Support for both RSpec and Minitest frameworks"
puts "• Comprehensive test requirements for each test type"
puts "• CLI integration with flexible options"
puts "• Doctor command integration for automated test generation"
puts "• Context-aware test instruction enhancement"