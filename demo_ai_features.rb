#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to show AI upgrade functionality
# This script demonstrates the new AI commands without requiring actual API keys

puts "🤖 RailsPlan AI Upgrade Demo"
puts "=============================="
puts ""

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

require "railsplan"
require "tmpdir"
require "fileutils"

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

def demo_index_command(dir)
  puts ""
  puts "🔍 Testing 'railsplan index' command..."
  
  Dir.chdir(dir) do
    index_command = RailsPlan::Commands::IndexCommand.new(verbose: true)
    success = index_command.execute
    
    if success
      puts "✅ Index command executed successfully"
      
      # Show what was extracted
      if File.exist?(".railsplan/context.json")
        context = JSON.parse(File.read(".railsplan/context.json"))
        puts ""
        puts "📊 Extracted Context:"
        puts "  App: #{context["app_name"]}"
        puts "  Models: #{context["models"]&.length || 0}"
        puts "  Tables: #{context["schema"]&.keys&.length || 0}"
        puts "  Controllers: #{context["controllers"]&.length || 0}"
        puts ""
      end
    else
      puts "❌ Index command failed"
    end
  end
end

def demo_ai_config
  puts ""
  puts "🤖 Testing AI configuration..."
  
  # Test config without API key
  config = RailsPlan::AIConfig.new
  puts "  Provider: #{config.provider}"
  puts "  Model: #{config.model}"
  puts "  Configured: #{config.configured?}"
  
  # Test config file creation
  config_path = RailsPlan::AIConfig.setup_config_file
  puts "  Config file: #{config_path}"
  puts "✅ AI configuration test completed"
end

def demo_generate_command_help(dir)
  puts ""
  puts "🛠️  Testing 'railsplan generate' command (help only)..."
  
  Dir.chdir(dir) do
    generate_command = RailsPlan::Commands::GenerateCommand.new(verbose: true)
    
    puts ""
    puts "ℹ️  To use the generate command, you would need to:"
    puts "  1. Set up AI provider credentials in ~/.railsplan/ai.yml"
    puts "  2. Or set environment variables like OPENAI_API_KEY"
    puts "  3. Then run: railsplan generate \"Add a Comment model with user and post associations\""
    puts ""
    puts "Example AI config file:"
    puts "  default:"
    puts "    provider: openai"
    puts "    model: gpt-4o"
    puts "    api_key: <%= ENV['OPENAI_API_KEY'] %>"
    puts ""
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
    
    # Test index command
    demo_index_command(demo_dir)
    
    # Show generate command help
    demo_generate_command_help(demo_dir)
    
    puts ""
    puts "🎉 Demo completed successfully!"
    puts ""
    puts "📖 To try the full AI functionality:"
    puts "  1. Install the gem: gem install railsplan"
    puts "  2. Create a new Rails app: railsplan new myapp"
    puts "  3. Set up AI credentials: ~/.railsplan/ai.yml"
    puts "  4. Index your app: railsplan index"
    puts "  5. Generate code: railsplan generate \"your instruction\""
  end
end

# Run the demo
main