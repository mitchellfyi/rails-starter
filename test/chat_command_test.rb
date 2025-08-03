# frozen_string_literal: true

require "test_helper"
require "railsplan/commands/chat_command"

class ChatCommandTest < ActiveSupport::TestCase
  def setup
    @command = RailsPlan::Commands::ChatCommand.new(verbose: false)
    
    # Create test config directory
    @test_config_dir = "/tmp/railsplan_test_#{SecureRandom.hex(8)}"
    FileUtils.mkdir_p(@test_config_dir)
    
    # Create a simple AI config for testing
    config_content = <<~YAML
      provider: openai
      openai_api_key: test_key
      model: gpt-4o
    YAML
    File.write(File.join(@test_config_dir, "ai.yml"), config_content)
  end
  
  def teardown
    FileUtils.rm_rf(@test_config_dir) if @test_config_dir && Dir.exist?(@test_config_dir)
  end
  
  test "chat command initializes successfully" do
    assert_not_nil @command
    assert_instance_of RailsPlan::Commands::ChatCommand, @command
  end
  
  test "determine_provider returns correct provider from options" do
    options = { provider: "claude" }
    provider = @command.send(:determine_provider, options)
    assert_equal :claude, provider
  end
  
  test "determine_provider falls back to default when no option provided" do
    options = {}
    provider = @command.send(:determine_provider, options)
    
    # Should return one of the available providers
    assert_includes RailsPlan::AI.available_providers, provider
  end
  
  test "execute returns true for valid single prompt" do
    # Mock the AI call to avoid actual API calls
    RailsPlan::AI.stubs(:call).returns({
      output: "Test response",
      metadata: { provider: :openai, model: "gpt-4o", tokens_used: 10, cost_estimate: 0.01 }
    })
    
    # Capture output to avoid cluttering test results
    capture_io do
      result = @command.execute("Test prompt", { provider: "openai" })
      assert result
    end
  end
  
  test "execute handles AI errors gracefully" do
    # Mock the AI call to raise an error
    RailsPlan::AI.stubs(:call).raises(RailsPlan::Error.new("API error"))
    
    # Capture output
    capture_io do
      result = @command.execute("Test prompt", { provider: "openai" })
      assert result # Should still return true as it handled the error
    end
  end
  
  test "build_generation_prompt creates appropriate prompt for Rails context" do
    instruction = "Create a User model"
    context = {
      "app_name" => "TestApp",
      "models" => [{"class_name" => "Post"}],
      "schema" => {"posts" => {"columns" => {"title" => {"type" => "string"}}}}
    }
    
    # Create a generate command to test prompt building
    generate_command = RailsPlan::Commands::GenerateCommand.new(verbose: false)
    prompt = generate_command.send(:build_generation_prompt, instruction, context)
    
    assert_includes prompt, instruction
    assert_includes prompt, "Rails developer"
    assert_includes prompt, "Generate complete, working Rails files"
  end
  
  test "parse_generation_response handles JSON format correctly" do
    json_output = '{"files": {"app/models/user.rb": "class User < ApplicationRecord\nend"}}'
    
    generate_command = RailsPlan::Commands::GenerateCommand.new(verbose: false)
    files = generate_command.send(:parse_generation_response, json_output, :json)
    
    assert_equal 1, files.size
    assert_includes files, "app/models/user.rb"
    assert_includes files["app/models/user.rb"], "class User"
  end
  
  test "parse_generation_response handles Ruby format correctly" do
    ruby_output = <<~RUBY
      # File: app/models/user.rb
      class User < ApplicationRecord
        validates :email, presence: true
      end
      
      # File: db/migrate/001_create_users.rb
      class CreateUsers < ActiveRecord::Migration[7.0]
        def change
          create_table :users do |t|
            t.string :email
            t.timestamps
          end
        end
      end
    RUBY
    
    generate_command = RailsPlan::Commands::GenerateCommand.new(verbose: false)
    files = generate_command.send(:parse_generation_response, ruby_output, :ruby)
    
    assert_equal 2, files.size
    assert_includes files, "app/models/user.rb"
    assert_includes files, "db/migrate/001_create_users.rb"
    assert_includes files["app/models/user.rb"], "class User"
    assert_includes files["db/migrate/001_create_users.rb"], "create_table :users"
  end
  
  test "extract_code_blocks handles markdown format correctly" do
    markdown_output = <<~MARKDOWN
      Here's your User model:
      
      ```ruby
      # app/models/user.rb
      class User < ApplicationRecord
        validates :email, presence: true
      end
      ```
      
      And here's the migration:
      
      ```ruby
      # db/migrate/001_create_users.rb
      class CreateUsers < ActiveRecord::Migration[7.0]
        def change
          create_table :users do |t|
            t.string :email
            t.timestamps
          end
        end
      end
      ```
    MARKDOWN
    
    generate_command = RailsPlan::Commands::GenerateCommand.new(verbose: false)
    files = generate_command.send(:extract_code_blocks, markdown_output)
    
    assert_equal 2, files.size
    assert_includes files, "app/models/user.rb"
    assert_includes files, "db/migrate/001_create_users.rb"
  end
  
  private
  
  def capture_io
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    yield
    
    [$stdout.string, $stderr.string]
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end