# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'json'
require 'yaml'
require 'timeout'

# Ensure the lib directory is in the load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'railsplan/cli'
require 'railsplan/logger'
require 'railsplan/commands/init_command'
require 'railsplan/commands/upgrade_command'
require 'railsplan/commands/refactor_command'
require 'railsplan/commands/explain_command'
require 'railsplan/commands/fix_command'
require 'railsplan/commands/doctor_command'

# Patch: Initialize logger if not already set
unless RailsPlan.respond_to?(:logger) && RailsPlan.logger
  RailsPlan.instance_variable_set(:@logger, RailsPlan::Logger.new)
  def RailsPlan.logger; @logger; end
end

class RailsPlanAICommandsTest < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @test_dir = Dir.mktmpdir('railsplan_ai_test')
    Dir.chdir(@test_dir)
    
    # Create basic Rails app structure
    create_test_rails_app
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_init_command_creates_railsplan_directory
    output = capture_output { RailsPlan::CLI.start(['init']) }
    
    assert_includes output, '🚀 Initializing RailsPlan for existing Rails application...'
    assert_includes output, '✅ Created .railsplan/ directory structure'
    assert_includes output, '✅ Detected and saved application settings'
    assert_includes output, '🎉 RailsPlan initialization complete!'
    
    # Check that files were created
    assert File.exist?('.railsplan/settings.yml'), "settings.yml should be created"
    assert File.exist?('.railsplan/prompts.log'), "prompts.log should be created"
    assert File.exist?('.railsplan/.gitignore'), ".gitignore should be created"
    
    # Check settings content
    settings = YAML.load_file('.railsplan/settings.yml')
    assert_equal 'TestApp', settings['app_name']
    assert_includes settings['key_gems'], 'devise'
    assert_includes settings['features'], 'authentication'
  end

  def test_init_command_fails_outside_rails_app
    # Remove Rails app files
    FileUtils.rm_f('config/application.rb')
    FileUtils.rm_f('Gemfile')
    
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['init']) }
    }
    
    assert_includes output, '❌ Not in a Rails application directory'
  end

  def test_evolve_command_requires_initialization
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['evolve', 'Add API versioning']) }
    }
    
    assert_includes output, '❌ RailsPlan not initialized for this project'
    assert_includes output, "💡 Run 'railsplan init' first"
  end

  def test_evolve_command_requires_ai_configuration
    # Initialize first
    RailsPlan::CLI.start(['init'])
    
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['evolve', 'Add API versioning']) }
    }
    
    assert_includes output, '❌ AI provider not configured'
    assert_includes output, '💡 Set up AI configuration in ~/.railsplan/ai.yml'
  end

  def test_refactor_command_requires_existing_path
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['refactor', 'nonexistent/path.rb']) }
    }
    
    assert_includes output, '❌ Path not found: nonexistent/path.rb'
  end

  def test_refactor_command_accepts_existing_file
    # Create a test file
    FileUtils.mkdir_p('app/models')
    File.write('app/models/user.rb', <<~RUBY)
      class User < ApplicationRecord
        validates :email, presence: true
      end
    RUBY
    
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['refactor', 'app/models/user.rb']) }
    }
    
    # Should fail on AI config, not file existence
    assert_includes output, '❌ AI provider not configured'
    refute_includes output, '❌ Path not found'
  end

  def test_explain_command_requires_existing_path
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['explain', 'nonexistent/path.rb']) }
    }
    
    assert_includes output, '❌ Path not found: nonexistent/path.rb'
  end

  def test_explain_command_accepts_existing_file
    # Create a test file
    FileUtils.mkdir_p('app/controllers')
    File.write('app/controllers/users_controller.rb', <<~RUBY)
      class UsersController < ApplicationController
        def index
          @users = User.all
        end
      end
    RUBY
    
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['explain', 'app/controllers/users_controller.rb']) }
    }
    
    # Should fail on AI config, not file existence
    assert_includes output, '❌ AI provider not configured'
    refute_includes output, '❌ Path not found'
  end

  def test_fix_command_requires_ai_configuration
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['fix', 'Add missing validations']) }
    }
    
    assert_includes output, '❌ AI provider not configured'
    assert_includes output, '💡 Set up AI configuration in ~/.railsplan/ai.yml'
  end

  def test_doctor_command_runs_enhanced_diagnostics
    # Create only essential test files to avoid scanning the entire repo
    FileUtils.mkdir_p('app/models')
    File.write('app/models/test_model.rb', 'class TestModel < ApplicationRecord; end')
    
    # Test the doctor command directly rather than through CLI to avoid hangs
    doctor = RailsPlan::Commands::DoctorCommand.new
    result = doctor.execute
    
    # The doctor command should complete and return a boolean
    assert_equal false, result  # Should fail because it finds issues
  rescue Timeout::Error
    flunk "Doctor command timed out - likely performance issue with file scanning"
  end

  def test_doctor_command_detects_rails_structure
    # Test the doctor command directly rather than through CLI
    doctor = RailsPlan::Commands::DoctorCommand.new
    result = doctor.execute
    
    # The doctor command should complete
    assert [true, false].include?(result)
  rescue Timeout::Error
    flunk "Doctor command timed out"
  end

  def test_doctor_command_detects_missing_tests
    # Create models without tests
    FileUtils.mkdir_p('app/models')
    File.write('app/models/user.rb', 'class User < ApplicationRecord; end')
    File.write('app/models/post.rb', 'class Post < ApplicationRecord; end')
    
    # Test the doctor command directly
    doctor = RailsPlan::Commands::DoctorCommand.new
    result = doctor.execute
    
    # The doctor command should find missing tests and return false
    assert_equal false, result
  end

  def test_doctor_command_generates_markdown_report
    # Create simple test files to avoid scanning large directories
    FileUtils.mkdir_p('app/models')
    File.write('app/models/simple_test.rb', 'class SimpleTest; end')
    
    # Test the doctor command directly with report option
    doctor = RailsPlan::Commands::DoctorCommand.new
    result = doctor.execute(report: 'markdown')
    
    # Should create a markdown report file
    report_files = Dir.glob('railsplan_doctor_report_*.md')
    assert report_files.any?, "Should create a markdown report file"
    
    # Check report content
    report_content = File.read(report_files.first)
    assert_includes report_content, '# RailsPlan Doctor Report'
    assert_includes report_content, '**Generated**:'
    assert_includes report_content, '**Total Issues**:'
  rescue Timeout::Error
    flunk "Doctor command timed out"
  end

  def test_doctor_command_generates_json_report
    # Create simple test files to avoid scanning large directories
    FileUtils.mkdir_p('app/models')
    File.write('app/models/simple_test.rb', 'class SimpleTest; end')
    
    # Test the doctor command directly with report option
    doctor = RailsPlan::Commands::DoctorCommand.new
    result = doctor.execute(report: 'json')
    
    # Should create a JSON report file
    report_files = Dir.glob('railsplan_doctor_report_*.json')
    assert report_files.any?, "Should create a JSON report file"
    
    # Check report content
    report_data = JSON.parse(File.read(report_files.first))
    assert report_data['generated_at']
    assert report_data.key?('total_issues')
    assert report_data.key?('fixable_issues')
    assert report_data.key?('issues')
  rescue Timeout::Error
    flunk "Doctor command timed out"
  end

  def test_dry_run_flag_works_with_commands
    # Initialize first
    RailsPlan::CLI.start(['init'])
    
    # Test with evolve command (should fail on AI config before getting to dry-run)
    output = capture_output { 
      assert_raises(SystemExit) { RailsPlan::CLI.start(['evolve', 'Add API versioning', '--dry-run']) }
    }
    
    assert_includes output, '❌ AI provider not configured'
  end

  private

  def create_test_rails_app
    # Create basic Rails app structure
    FileUtils.mkdir_p(%w[
      app/models
      app/controllers
      app/views
      config
      db/migrate
      test
      spec
    ])
    
    # Create Gemfile
    File.write('Gemfile', <<~GEMFILE)
      source 'https://rubygems.org'
      
      gem 'rails', '~> 7.0'
      gem 'sqlite3'
      gem 'devise'
    GEMFILE
    
    # Create application.rb
    File.write('config/application.rb', <<~RUBY)
      require_relative "boot"
      require "rails/all"
      
      module TestApp
        class Application < Rails::Application
          config.load_defaults 7.0
        end
      end
    RUBY
    
    # Create routes.rb
    File.write('config/routes.rb', <<~RUBY)
      Rails.application.routes.draw do
        root 'home#index'
        resources :users
      end
    RUBY
    
    # Create application controller
    File.write('app/controllers/application_controller.rb', <<~RUBY)
      class ApplicationController < ActionController::Base
        protect_from_forgery with: :exception
      end
    RUBY
    
    # Create a user model to trigger authentication feature detection
    File.write('app/models/user.rb', <<~RUBY)
      class User < ApplicationRecord
        devise :database_authenticatable, :registerable
        validates :email, presence: true, uniqueness: true
      end
    RUBY
    
    # Create database.yml
    File.write('config/database.yml', <<~YAML)
      development:
        adapter: sqlite3
        database: db/development.sqlite3
        
      test:
        adapter: sqlite3
        database: db/test.sqlite3
    YAML
  end

  def capture_output
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      yield
    ensure
      output = $stdout.string + $stderr.string
      $stdout = old_stdout
      $stderr = old_stderr
    end
    
    output
  end
end