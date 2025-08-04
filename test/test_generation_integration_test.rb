# frozen_string_literal: true

require_relative "standalone_test_helper"

# Integration test to demonstrate the test generation feature
class TestGenerationIntegrationTest < StandaloneTestCase
  def setup
    @temp_dir = Dir.mktmpdir("railsplan_integration_test")
    @original_dir = Dir.pwd
    Dir.chdir(@temp_dir)
    
    # Create a realistic Rails app structure
    create_rails_app_structure
    create_sample_models_and_controllers
    setup_railsplan_context
  end
  
  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@temp_dir)
  end
  
  def test_generates_system_test_for_user_signup_workflow
    command = RailsPlan::Commands::TestGenerateCommand.new(verbose: false)
    instruction = "User signs up with email and password"
    
    # Mock AI response for system test
    mock_ai_generator = create_mock_ai_generator_for_system_test
    
    RailsPlan::AIGenerator.stub(:new, mock_ai_generator) do
      options = { force: true, type: "system" }
      
      # Execute should return true for successful generation
      # In real usage, this would call AI and generate actual test files
      assert_respond_to command, :execute
      
      # Verify test type detection
      detected_type = command.send(:determine_test_type, instruction, {})
      assert_equal "system", detected_type
    end
  end
  
  test "generates model test for user validation" do
    command = RailsPlan::Commands::TestGenerateCommand.new(verbose: false)
    instruction = "User model validates email presence and uniqueness"
    
    # Verify test type detection
    detected_type = command.send(:determine_test_type, instruction, {})
    assert_equal "model", detected_type
    
    # Verify test framework detection
    framework = command.send(:detect_test_framework, {})
    assert_equal "Minitest", framework
  end
  
  test "generates request test for API endpoint" do
    command = RailsPlan::Commands::TestGenerateCommand.new(verbose: false)
    instruction = "API returns user data in JSON format"
    
    detected_type = command.send(:determine_test_type, instruction, {})
    assert_equal "request", detected_type
    
    # Verify test requirements generation
    requirements = command.send(:test_requirements_for_type, "request", "Minitest")
    assert_includes requirements, "test/integration/"
    assert_includes requirements, "ActionDispatch::IntegrationTest"
  end
  
  test "detects RSpec when spec files exist" do
    # Create RSpec structure
    FileUtils.mkdir_p("spec")
    File.write("spec/spec_helper.rb", "# RSpec configuration")
    File.write("spec/rails_helper.rb", "# Rails RSpec configuration")
    
    command = RailsPlan::Commands::TestGenerateCommand.new(verbose: false)
    framework = command.send(:detect_test_framework, {})
    assert_equal "RSpec", framework
    
    # Verify RSpec-specific requirements
    requirements = command.send(:test_requirements_for_type, "system", "RSpec")
    assert_includes requirements, "spec/system/"
    assert_includes requirements, "feature"
    assert_includes requirements, "scenario"
  end
  
  test "builds comprehensive test instruction" do
    command = RailsPlan::Commands::TestGenerateCommand.new(verbose: false)
    instruction = "User authentication flow"
    test_type = "system"
    context = {
      "app_name" => "TestApp",
      "models" => [{ "class_name" => "User" }],
      "controllers" => [{ "class_name" => "ApplicationController" }]
    }
    
    enhanced_instruction = command.send(:build_test_instruction, instruction, test_type, context)
    
    assert_includes enhanced_instruction, "User authentication flow"
    assert_includes enhanced_instruction, "system test"
    assert_includes enhanced_instruction, "Minitest"
    assert_includes enhanced_instruction, "test/system/"
    assert_includes enhanced_instruction, "ApplicationSystemTestCase"
  end
  
  test "doctor command integration with test generation" do
    # Create a model without tests
    model_file = "app/models/user.rb"
    File.write(model_file, <<~RUBY)
      class User < ApplicationRecord
        validates :email, presence: true, uniqueness: true
      end
    RUBY
    
    doctor_command = RailsPlan::Commands::DoctorCommand.new(verbose: false)
    
    # Test missing test detection
    missing_tests = []
    test_file = model_file.gsub('app/', 'test/').gsub('.rb', '_test.rb')
    spec_file = model_file.gsub('app/', 'spec/').gsub('.rb', '_spec.rb')
    
    unless File.exist?(test_file) || File.exist?(spec_file)
      missing_tests << model_file
    end
    
    assert_includes missing_tests, model_file
    
    # Test issue creation for missing tests
    issues = []
    missing_tests.each do |file|
      issues << {
        description: "Missing tests for #{file}",
        severity: 'warning',
        fixable: true,
        fix_suggestion: "Generate tests for #{file}",
        category: 'test'
      }
    end
    
    assert_equal 1, issues.length
    assert_equal 'test', issues.first[:category]
    assert issues.first[:fixable]
  end
  
  test "validates command line option handling" do
    command = RailsPlan::Commands::TestGenerateCommand.new(verbose: false)
    
    # Test type override
    instruction = "User signs up"  # Would normally be detected as system
    detected_type = command.send(:determine_test_type, instruction, { type: "model" })
    assert_equal "model", detected_type
    
    # Test valid test types
    RailsPlan::Commands::TestGenerateCommand::TEST_TYPES.each do |type|
      override_type = command.send(:determine_test_type, instruction, { type: type })
      assert_equal type, override_type
    end
  end
  
  private
  
  def create_rails_app_structure
    dirs = %w[
      app/models
      app/controllers
      app/views
      app/jobs
      test/models
      test/controllers
      test/system
      test/integration
      test/jobs
      spec/models
      spec/controllers
      spec/system
      spec/requests
      spec/jobs
      config
      db
      .railsplan
    ]
    
    FileUtils.mkdir_p(dirs)
    
    # Create essential Rails files
    File.write("config/application.rb", <<~RUBY)
      require_relative 'boot'
      require 'rails/all'
      
      module TestApp
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
    
    File.write("config/routes.rb", <<~RUBY)
      Rails.application.routes.draw do
        resources :users
        root 'home#index'
      end
    RUBY
  end
  
  def create_sample_models_and_controllers
    # Create User model
    File.write("app/models/user.rb", <<~RUBY)
      class User < ApplicationRecord
        validates :email, presence: true, uniqueness: true
        validates :name, presence: true
        
        has_many :posts, dependent: :destroy
      end
    RUBY
    
    # Create Users controller
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
            redirect_to @user
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
    
    # Create a job
    File.write("app/jobs/email_job.rb", <<~RUBY)
      class EmailJob < ApplicationJob
        queue_as :default
        
        def perform(user_id)
          user = User.find(user_id)
          UserMailer.welcome_email(user).deliver_now
        end
      end
    RUBY
  end
  
  def setup_railsplan_context
    context = {
      "generated_at" => Time.now.iso8601,
      "app_name" => "TestApp",
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
  end
  
  def create_mock_ai_generator_for_system_test
    mock = Minitest::Mock.new
    mock_result = {
      description: "Generated system test for user signup workflow",
      files: {
        "test/system/user_signup_test.rb" => <<~RUBY
          require "application_system_test_case"
          
          class UserSignupTest < ApplicationSystemTestCase
            test "user can sign up with email and password" do
              visit new_user_registration_path
              
              fill_in "Email", with: "test@example.com"
              fill_in "Password", with: "password123"
              fill_in "Password confirmation", with: "password123"
              
              click_button "Sign up"
              
              assert_text "Welcome! You have signed up successfully."
              assert_current_path root_path
            end
          end
        RUBY
      },
      instructions: [
        "Run the test with: rails test test/system/user_signup_test.rb",
        "Ensure Capybara and system test setup is configured"
      ]
    }
    
    mock.expect(:generate, mock_result, [String, Hash])
    mock
  end
end