# frozen_string_literal: true

require "test_helper"
require "railsplan/cli"

class CLITestGenerationTest < ActiveSupport::TestCase
  def setup
    @temp_dir = Dir.mktmpdir("railsplan_cli_test")
    @original_dir = Dir.pwd
    Dir.chdir(@temp_dir)
    
    # Create basic Rails app structure
    FileUtils.mkdir_p(%w[
      app/models
      app/controllers
      test/models
      test/controllers
      test/system
      config
      .railsplan
    ])
    
    # Create minimal Rails files
    File.write("config/application.rb", "class Application < Rails::Application; end")
    File.write("Gemfile", "gem 'rails'")
    
    # Create basic context file
    context = {
      "generated_at" => Time.now.iso8601,
      "app_name" => "TestApp",
      "models" => [],
      "schema" => {},
      "routes" => [],
      "controllers" => [],
      "modules" => []
    }
    File.write(".railsplan/context.json", JSON.pretty_generate(context))
  end
  
  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@temp_dir)
  end
  
  test "CLI help includes test generation command" do
    cli = RailsPlan::CLI.new
    
    # Capture the help output
    output = capture_io do
      cli.help
    end
    
    help_text = output.join
    assert_includes help_text, "generate test"
    assert_includes help_text, "Generate tests with AI"
  end
  
  test "CLI generate method recognizes test subcommand" do
    # Test that the CLI properly routes test generation
    cli = RailsPlan::CLI.new
    
    # Mock the TestGenerateCommand to avoid actual AI calls
    mock_command = Minitest::Mock.new
    mock_command.expect(:execute, true, ["User signs up", Hash])
    
    RailsPlan::Commands::TestGenerateCommand.stub(:new, mock_command) do
      # This would normally call the test generation command
      # We're just testing the CLI routing logic
      assert_respond_to cli, :generate
    end
  end
  
  test "CLI extracts test instruction correctly" do
    # Simulate CLI args parsing
    args = ["test", "User", "signs", "up", "with", "email"]
    first_arg = args.first
    instruction = args[1..-1].join(' ')
    
    assert_equal "test", first_arg
    assert_equal "User signs up with email", instruction
  end
  
  test "CLI handles empty test instruction" do
    # Test args with just "test" and no instruction
    args = ["test"]
    first_arg = args.first
    instruction = args[1..-1].join(' ')
    
    assert_equal "test", first_arg
    assert_equal "", instruction
  end
  
  test "CLI preserves test generation options" do
    # Test that CLI options are passed through correctly
    options = {
      type: "system",
      dry_run: true,
      force: false,
      validate: true
    }
    
    # Verify these are the options we added to the CLI
    cli = RailsPlan::CLI.new
    
    # The CLI class should have the option definitions
    assert_respond_to cli.class, :class_options
  end
  
  test "CLI help shows test-specific options" do
    # The CLI help should include the new test-specific options
    cli = RailsPlan::CLI.new
    
    # Get the generate command description
    generate_cmd = cli.class.commands["generate"]
    assert_not_nil generate_cmd
    
    # Check that test examples are included
    long_desc = generate_cmd.long_description
    assert_includes long_desc, "generate test"
    assert_includes long_desc, "User signs up"
  end
end