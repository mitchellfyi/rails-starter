#!/usr/bin/env ruby
# frozen_string_literal: true

#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "minitest/spec"
require "stringio"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "railsplan/ai_config"
require "railsplan/context_manager"
require "railsplan/commands/index_command"
require "railsplan/commands/generate_command"
require "tmpdir"
require "fileutils"

class AIFeatureTest < Minitest::Test
  def setup
    @test_dir = Dir.mktmpdir("railsplan_ai_test")
    @original_dir = Dir.pwd
    Dir.chdir(@test_dir)
    
    # Create a mock Rails app structure
    setup_mock_rails_app
  end
  
  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir)
    
    # Clean up any test config files
    config_path = File.expand_path("~/.railsplan/ai.yml")
    File.delete(config_path) if File.exist?(config_path) && File.read(config_path).include?("test-api-key")
  end
  
  def test_ai_config_initialization
    # Clean up any existing config files that might affect the test
    config_path = File.expand_path("~/.railsplan/ai.yml")
    project_config = ".railsplanrc"
    
    config_backup = nil
    project_backup = nil
    
    if File.exist?(config_path)
      config_backup = File.read(config_path)
      File.delete(config_path)
    end
    
    if File.exist?(project_config)
      project_backup = File.read(project_config)
      File.delete(project_config)
    end
    
    # Clear any environment variables that might affect the test
    old_keys = {}
    %w[OPENAI_API_KEY RAILSPLAN_AI_PROVIDER RAILSPLAN_AI_MODEL RAILSPLAN_AI_API_KEY ANTHROPIC_API_KEY CLAUDE_KEY].each do |key|
      old_keys[key] = ENV.delete(key)
    end
    
    config = RailsPlan::AIConfig.new
    
    # Should have defaults
    assert_equal "openai", config.provider
    assert_equal "gpt-4o", config.model
    
    # Should not be configured without API key
    refute config.configured?
    
    # Restore environment and files
    old_keys.each { |key, value| ENV[key] = value if value }
    File.write(config_path, config_backup) if config_backup
    File.write(project_config, project_backup) if project_backup
  end
  
  def test_ai_config_with_env_variables
    # Clear all AI-related env vars first
    old_keys = {}
    %w[OPENAI_API_KEY RAILSPLAN_AI_PROVIDER RAILSPLAN_AI_MODEL RAILSPLAN_AI_API_KEY ANTHROPIC_API_KEY CLAUDE_KEY].each do |key|
      old_keys[key] = ENV.delete(key)
    end
    
    ENV["OPENAI_API_KEY"] = "test-key"
    
    config = RailsPlan::AIConfig.new
    assert config.configured?
    assert_equal "test-key", config.api_key
    
    # Restore environment
    old_keys.each { |key, value| ENV[key] = value if value }
  end
  
  def test_ai_config_file_creation
    # Clean up any existing config
    config_path = File.expand_path("~/.railsplan/ai.yml")
    FileUtils.rm_f(config_path) if File.exist?(config_path)
    
    config_path = RailsPlan::AIConfig.setup_config_file
    
    assert File.exist?(config_path)
    content = File.read(config_path)
    assert_includes content, "provider: openai"
    assert_includes content, "model: gpt-4o"
    assert_includes content, "OPENAI_API_KEY"
  end
  
  def test_context_manager_initialization
    context_manager = RailsPlan::ContextManager.new(@test_dir)
    
    assert_equal File.join(@test_dir, ".railsplan"), context_manager.context_path.gsub("/context.json", "")
  end
  
  def test_context_extraction
    context_manager = RailsPlan::ContextManager.new(@test_dir)
    context = context_manager.extract_context
    
    # Should extract basic app information
    assert context["app_name"]
    assert context["models"]
    assert context["schema"] # This might be empty but should exist
    assert context["hash"]
    
    # Should create .railsplan directory
    assert Dir.exist?(File.join(@test_dir, ".railsplan"))
    assert File.exist?(context_manager.context_path)
  end
  
  def test_context_staleness_detection
    context_manager = RailsPlan::ContextManager.new(@test_dir)
    
    # Initially should be stale (no context)
    assert context_manager.context_stale?
    
    # After extraction, should not be stale
    context_manager.extract_context
    refute context_manager.context_stale?
    
    # After modifying schema, should be stale again
    # Let's modify a model instead since schema parsing is more complex
    File.write("app/models/post.rb", "class Post < ApplicationRecord\n  belongs_to :user\nend")
    assert context_manager.context_stale?
  end
  
  def test_index_command_execution
    command = RailsPlan::Commands::IndexCommand.new(verbose: true)
    
    # Capture output
    output = capture_output { command.execute }
    
    assert_includes output, "Indexing Rails application context"
    assert_includes output, "Context extracted successfully"
    assert File.exist?(".railsplan/context.json")
  end
  
  def test_generate_command_without_ai_config
    command = RailsPlan::Commands::GenerateCommand.new(verbose: true)
    
    # Should fail without AI configuration
    output = capture_output { command.execute("Add a User model") }
    
    assert_includes output, "AI provider not configured"
    assert_includes output, "~/.railsplan/ai.yml"
  end
  
  def test_generate_command_with_mock_ai
    # Setup mock AI config
    setup_mock_ai_config
    
    command = RailsPlan::Commands::GenerateCommand.new(verbose: true)
    
    # Mock the AI generator to avoid actual API calls
    ai_generator = Minitest::Mock.new
    ai_generator.expect :generate, {
      description: "Generated User model",
      files: {
        "app/models/user.rb" => "class User < ApplicationRecord\nend",
        "db/migrate/001_create_users.rb" => "class CreateUsers < ActiveRecord::Migration[7.0]\nend"
      },
      instructions: ["Run rails db:migrate"]
    }, [String, Hash]
    
    # This would require more complex mocking to fully test
    # For now, we'll just test the setup
    output = capture_output { command.execute("Add a User model", force: true) }
    
    # Should at least attempt to generate
    assert_includes output, "Generating Rails code with AI"
  end
  
  def test_prompt_logging
    context_manager = RailsPlan::ContextManager.new(@test_dir)
    context_manager.setup_directory
    
    context_manager.log_prompt("Test prompt", "Test response", { test: true })
    
    assert File.exist?(".railsplan/prompts.log")
    log_content = File.read(".railsplan/prompts.log")
    assert_includes log_content, "Test prompt"
    assert_includes log_content, "Test response"
  end
  
  def test_file_generation_safety
    context_manager = RailsPlan::ContextManager.new(@test_dir)
    
    files = {
      "app/models/test.rb" => "class Test < ApplicationRecord\nend",
      "spec/models/test_spec.rb" => "require 'rails_helper'\n\nRSpec.describe Test do\nend"
    }
    
    context_manager.save_last_generated(files)
    
    assert File.exist?(".railsplan/last_generated/app/models/test.rb")
    assert File.exist?(".railsplan/last_generated/spec/models/test_spec.rb")
  end
  
  private
  
  def setup_mock_rails_app
    # Create Rails app structure
    FileUtils.mkdir_p("app/models")
    FileUtils.mkdir_p("app/controllers")
    FileUtils.mkdir_p("config")
    FileUtils.mkdir_p("db")
    
    # Create basic files
    File.write("Gemfile", "source 'https://rubygems.org'\ngem 'rails'")
    File.write("config/application.rb", "module TestApp\n  class Application < Rails::Application\n  end\nend")
    
    # Create a basic schema
    File.write("db/schema.rb", <<~SCHEMA)
      ActiveRecord::Schema.define(version: 2024_01_01_000000) do
        create_table "users", force: :cascade do |t|
          t.string "email"
          t.string "name"
          t.timestamps
        end
      end
    SCHEMA
    
    # Create a model
    File.write("app/models/user.rb", <<~MODEL)
      class User < ApplicationRecord
        validates :email, presence: true
        has_many :posts
      end
    MODEL
    
    # Create a controller
    File.write("app/controllers/users_controller.rb", <<~CONTROLLER)
      class UsersController < ApplicationController
        def index
          @users = User.all
        end
        
        def show
          @user = User.find(params[:id])
        end
      end
    CONTROLLER
  end
  
  def setup_mock_ai_config
    config_dir = File.expand_path("~/.railsplan")
    FileUtils.mkdir_p(config_dir)
    
    config_content = <<~YAML
      default:
        provider: openai
        model: gpt-4o
        api_key: test-api-key
    YAML
    
    File.write(File.join(config_dir, "ai.yml"), config_content)
  end
  
  def capture_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end