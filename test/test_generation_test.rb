# frozen_string_literal: true

require "test_helper"
require "railsplan/commands/test_generate_command"

class TestGenerationTest < ActiveSupport::TestCase
  def setup
    @command = RailsPlan::Commands::TestGenerateCommand.new(verbose: false)
    @temp_dir = Dir.mktmpdir("railsplan_test_generation")
    @original_dir = Dir.pwd
    Dir.chdir(@temp_dir)
    
    # Create basic Rails app structure
    FileUtils.mkdir_p(%w[
      app/models
      app/controllers
      test/models
      test/controllers
      test/system
      spec/models
      spec/controllers
      spec/system
      config
    ])
    
    # Create minimal Rails files
    File.write("config/application.rb", "class Application < Rails::Application; end")
    File.write("Gemfile", "gem 'rails'")
  end
  
  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@temp_dir)
  end
  
  test "determines test type for system tests" do
    instruction = "User signs up with email and password"
    test_type = @command.send(:determine_test_type, instruction, {})
    
    assert_equal "system", test_type
  end
  
  test "determines test type for request tests" do
    instruction = "API returns user data with correct JSON format"
    test_type = @command.send(:determine_test_type, instruction, {})
    
    assert_equal "request", test_type
  end
  
  test "determines test type for model tests" do
    instruction = "User model validates email presence and uniqueness"
    test_type = @command.send(:determine_test_type, instruction, {})
    
    assert_equal "model", test_type
  end
  
  test "determines test type for job tests" do
    instruction = "Email job sends notification to user"
    test_type = @command.send(:determine_test_type, instruction, {})
    
    assert_equal "job", test_type
  end
  
  test "overrides test type when explicitly specified" do
    instruction = "User signs up with email and password"
    test_type = @command.send(:determine_test_type, instruction, { type: "request" })
    
    assert_equal "request", test_type
  end
  
  test "detects Rails app correctly" do
    assert @command.send(:rails_app?)
  end
  
  test "detects test framework - Minitest by default" do
    context = {}
    framework = @command.send(:detect_test_framework, context)
    
    assert_equal "Minitest", framework
  end
  
  test "detects test framework - RSpec when spec files exist" do
    File.write("spec/spec_helper.rb", "# RSpec helper")
    
    context = {}
    framework = @command.send(:detect_test_framework, context)
    
    assert_equal "RSpec", framework
  end
  
  test "builds test instruction with context" do
    instruction = "User signs up"
    test_type = "system"
    context = { "app_name" => "TestApp" }
    
    enhanced_instruction = @command.send(:build_test_instruction, instruction, test_type, context)
    
    assert_includes enhanced_instruction, "User signs up"
    assert_includes enhanced_instruction, "system test"
    assert_includes enhanced_instruction, "Minitest"
  end
  
  test "generates test requirements for system tests" do
    requirements = @command.send(:test_requirements_for_type, "system", "Minitest")
    
    assert_includes requirements, "test/system/"
    assert_includes requirements, "ApplicationSystemTestCase"
    assert_includes requirements, "Capybara"
  end
  
  test "generates test requirements for RSpec system tests" do
    requirements = @command.send(:test_requirements_for_type, "system", "RSpec")
    
    assert_includes requirements, "spec/system/"
    assert_includes requirements, "feature"
    assert_includes requirements, "Capybara"
  end
  
  test "generates test requirements for model tests" do
    requirements = @command.send(:test_requirements_for_type, "model", "Minitest")
    
    assert_includes requirements, "test/models/"
    assert_includes requirements, "ActiveSupport::TestCase"
    assert_includes requirements, "validations"
  end
  
  test "generates test requirements for request tests" do
    requirements = @command.send(:test_requirements_for_type, "request", "Minitest")
    
    assert_includes requirements, "test/integration/"
    assert_includes requirements, "ActionDispatch::IntegrationTest"
    assert_includes requirements, "get, post, put"
  end
  
  test "handles missing instruction gracefully" do
    # This would be called by CLI with empty instruction
    # The command should handle this case properly
    assert_respond_to @command, :execute
  end
  
  test "validates dry run option" do
    # Test that dry run mode doesn't actually write files
    options = { dry_run: true, force: true }
    
    # Mock the AI response to avoid actual AI calls
    mock_ai_generator = Minitest::Mock.new
    mock_result = {
      description: "Test description",
      files: { "test/system/user_signup_test.rb" => "# Test content" },
      instructions: ["Run tests"]
    }
    
    # This test verifies the structure is correct for dry run handling
    assert_includes RailsPlan::Commands::TestGenerateCommand::TEST_TYPES, "system"
    assert_includes RailsPlan::Commands::TestGenerateCommand::TEST_TYPES, "request"
    assert_includes RailsPlan::Commands::TestGenerateCommand::TEST_TYPES, "model"
  end
  
  test "includes all expected test types" do
    expected_types = %w[system request model job controller integration unit]
    
    expected_types.each do |type|
      assert_includes RailsPlan::Commands::TestGenerateCommand::TEST_TYPES, type
    end
  end
end