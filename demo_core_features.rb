#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple demo script to show AI upgrade core functionality
# This script demonstrates the new AI features without requiring Thor or other dependencies

puts "🤖 RailsPlan AI Core Features Demo"
puts "==================================="
puts ""

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

require "railsplan/ai_config"
require "railsplan/context_manager"
require "railsplan/commands/index_command"
require "tmpdir"
require "fileutils"
require "json"

def create_demo_rails_app(dir)
  puts "📁 Creating demo Rails app structure..."
  
  # Create Rails app structure
  FileUtils.mkdir_p("#{dir}/app/models")
  FileUtils.mkdir_p("#{dir}/app/controllers")
  FileUtils.mkdir_p("#{dir}/config")
  FileUtils.mkdir_p("#{dir}/db")
  
  # Create basic files
  File.write("#{dir}/Gemfile", "source 'https://rubygems.org'\ngem 'rails'")
  File.write("#{dir}/config/application.rb", "module DemoApp\n  class Application < Rails::Application\n  end\nend")
  
  # Create a basic schema
  File.write("#{dir}/db/schema.rb", <<~SCHEMA)
    ActiveRecord::Schema.define(version: 2024_01_01_000000) do
      create_table "users", force: :cascade do |t|
        t.string "email"
        t.string "name"
        t.timestamps
      end
      
      create_table "posts", force: :cascade do |t|
        t.string "title"
        t.text "content"
        t.references :user, null: false, foreign_key: true
        t.timestamps
      end
    end
  SCHEMA
  
  # Create models
  File.write("#{dir}/app/models/user.rb", <<~MODEL)
    class User < ApplicationRecord
      validates :email, presence: true, uniqueness: true
      has_many :posts, dependent: :destroy
    end
  MODEL
  
  File.write("#{dir}/app/models/post.rb", <<~MODEL)
    class Post < ApplicationRecord
      belongs_to :user
      validates :title, presence: true
      validates :content, presence: true
    end
  MODEL
  
  # Create controllers
  File.write("#{dir}/app/controllers/users_controller.rb", <<~CONTROLLER)
    class UsersController < ApplicationController
      def index
        @users = User.all
      end
      
      def show
        @user = User.find(params[:id])
      end
    end
  CONTROLLER
  
  puts "✅ Demo Rails app created"
end

def demo_context_extraction(dir)
  puts ""
  puts "🔍 Testing context extraction..."
  
  Dir.chdir(dir) do
    context_manager = RailsPlan::ContextManager.new(Dir.pwd)
    context = context_manager.extract_context
    
    puts "✅ Context extracted successfully!"
    puts ""
    puts "📊 Extracted Context:"
    puts "  App: #{context["app_name"]}"
    puts "  Models: #{context["models"]&.length || 0}"
    
    if context["models"] && !context["models"].empty?
      context["models"].each do |model|
        puts "    - #{model["class_name"]}"
        if model["associations"] && !model["associations"].empty?
          model["associations"].each do |assoc|
            puts "      #{assoc["type"]} :#{assoc["name"]}"
          end
        end
      end
    end
    
    puts "  Database tables: #{context["schema"]&.keys&.length || 0}"
    if context["schema"] && !context["schema"].empty?
      context["schema"].keys.each do |table|
        puts "    - #{table}"
        columns = context["schema"][table]["columns"]
        if columns && !columns.empty?
          columns.each do |col_name, col_info|
            puts "      #{col_name}: #{col_info["type"]}"
          end
        end
      end
    end
    
    puts "  Controllers: #{context["controllers"]&.length || 0}"
    if context["controllers"] && !context["controllers"].empty?
      context["controllers"].each do |controller|
        puts "    - #{controller["class_name"]}"
      end
    end
    
    puts ""
    puts "📁 Context saved to .railsplan/context.json"
    puts "📝 Context file size: #{File.size('.railsplan/context.json')} bytes"
  end
end

def demo_ai_config
  puts ""
  puts "🤖 Testing AI configuration..."
  
  # Test config without API key
  config = RailsPlan::AIConfig.new
  puts "  Default provider: #{config.provider}"
  puts "  Default model: #{config.model}"
  puts "  Configured: #{config.configured?}"
  
  # Test config file creation
  config_path = RailsPlan::AIConfig.setup_config_file
  puts "  Config file created: #{config_path}"
  
  if File.exist?(config_path)
    puts "  Config file exists: ✅"
    puts "  Config file size: #{File.size(config_path)} bytes"
  end
  
  puts "✅ AI configuration test completed"
end

def demo_prompt_logging(dir)
  puts ""
  puts "📝 Testing prompt logging..."
  
  Dir.chdir(dir) do
    context_manager = RailsPlan::ContextManager.new(Dir.pwd)
    
    # Log a sample prompt/response
    sample_prompt = "Generate a Rails model for a Product with name, price, and description"
    sample_response = '{"description": "Generated Product model", "files": {"app/models/product.rb": "class Product < ApplicationRecord\\n  validates :name, presence: true\\nend"}}'
    
    context_manager.log_prompt(sample_prompt, sample_response, {
      provider: "openai",
      model: "gpt-4o",
      instruction: sample_prompt
    })
    
    if File.exist?(".railsplan/prompts.log")
      puts "✅ Prompt logged successfully"
      puts "📁 Log file: .railsplan/prompts.log"
      puts "📝 Log file size: #{File.size('.railsplan/prompts.log')} bytes"
      
      # Show last log entry
      log_entries = File.readlines(".railsplan/prompts.log")
      if !log_entries.empty?
        last_entry = JSON.parse(log_entries.last)
        puts "📄 Last log entry timestamp: #{last_entry["timestamp"]}"
        puts "📄 Last log entry prompt: #{last_entry["prompt"][0..50]}..."
      end
    else
      puts "❌ Prompt logging failed"
    end
  end
end

def demo_staleness_detection(dir)
  puts ""
  puts "🔄 Testing staleness detection..."
  
  Dir.chdir(dir) do
    context_manager = RailsPlan::ContextManager.new(Dir.pwd)
    
    puts "  Initial state (no context): #{context_manager.context_stale? ? 'stale ✅' : 'fresh ❌'}"
    
    # Extract context
    context_manager.extract_context
    puts "  After extraction: #{context_manager.context_stale? ? 'stale ❌' : 'fresh ✅'}"
    
    # Modify a model
    File.write("app/models/user.rb", <<~MODEL)
      class User < ApplicationRecord
        validates :email, presence: true, uniqueness: true
        validates :name, presence: true # Added validation
        has_many :posts, dependent: :destroy
      end
    MODEL
    
    puts "  After model modification: #{context_manager.context_stale? ? 'stale ✅' : 'fresh ❌'}"
    puts "✅ Staleness detection working"
  end
end

def main
  # Create temporary directory for demo
  Dir.mktmpdir("railsplan_demo") do |demo_dir|
    puts "📂 Demo directory: #{demo_dir}"
    
    # Create demo Rails app
    create_demo_rails_app(demo_dir)
    
    # Test AI configuration
    demo_ai_config
    
    # Test context extraction
    demo_context_extraction(demo_dir)
    
    # Test prompt logging
    demo_prompt_logging(demo_dir)
    
    # Test staleness detection
    demo_staleness_detection(demo_dir)
    
    puts ""
    puts "🎉 Demo completed successfully!"
    puts ""
    puts "📖 To try the full AI functionality:"
    puts "  1. Install the gem: gem install railsplan"
    puts "  2. Create a new Rails app: railsplan new myapp"
    puts "  3. Set up AI credentials: ~/.railsplan/ai.yml"
    puts "  4. Index your app: railsplan index"
    puts "  5. Generate code: railsplan generate \"your instruction\""
    puts ""
    puts "🔧 Available AI commands:"
    puts "  railsplan index                           # Extract app context"
    puts "  railsplan generate \"Add Comment model\"    # Generate with AI"
    puts "  railsplan generate \"...\" --profile=test   # Use specific AI profile"
  end
end

# Run the demo
begin
  main
rescue => e
  puts "❌ Demo failed: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end