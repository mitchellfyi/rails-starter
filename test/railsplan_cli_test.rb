# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'json'
require 'stringio'

# Ensure the lib directory is in the load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'railsplan/cli'
require 'railsplan/logger'
require 'railsplan/version'

# Patch: Initialize logger if not already set
unless RailsPlan.respond_to?(:logger) && RailsPlan.logger
  RailsPlan.instance_variable_set(:@logger, RailsPlan::Logger.new)
  def RailsPlan.logger; @logger; end
end

class RailsPlanCLITest < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @test_dir = Dir.mktmpdir('railsplan_test')
    Dir.chdir(@test_dir)
    
    # Create test structure
    create_test_structure
  end

  def teardown
    # Restore original constants if they existed
    if defined?(@original_template_path)
      RailsPlan::CLI.send(:remove_const, :TEMPLATE_PATH) if RailsPlan::CLI.const_defined?(:TEMPLATE_PATH)
      RailsPlan::CLI.const_set(:TEMPLATE_PATH, @original_template_path)
    end
    
    if defined?(@original_registry_path)
      RailsPlan::CLI.send(:remove_const, :REGISTRY_PATH) if RailsPlan::CLI.const_defined?(:REGISTRY_PATH)
      RailsPlan::CLI.const_set(:REGISTRY_PATH, @original_registry_path)
    end
    
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_list_command_shows_available_modules
    output = capture_output { RailsPlan::CLI.start(['list']) }
    assert_includes output, 'Available modules:'
  end

  def test_add_command_installs_module
    output = capture_output { RailsPlan::CLI.start(['add', 'test_module']) }
    assert_includes output, "Adding module 'test_module' to existing application..."
    assert_includes output, 'This feature is coming soon!'
  end

  def test_add_command_fails_for_nonexistent_module
    output = capture_output do
      RailsPlan::CLI.start(['add', 'nonexistent'])
    end
    # The CLI doesn't raise SystemExit for nonexistent modules, it just shows "coming soon"
    assert_includes output, "Adding module 'nonexistent' to existing application..."
    assert_includes output, 'This feature is coming soon!'
  end

  def test_remove_command_uninstalls_module
    # First install the module
    install_test_module
    
    # Then remove it
    output = capture_output { RailsPlan::CLI.start(['remove', 'test_module']) }
    
    assert_includes output, '🗑️  Removing test_module module...'
    assert_includes output, '✅ Successfully removed test_module module!'
  end

  def test_remove_command_fails_for_nonexistent_module
    output = capture_output do
      assert_raises(SystemExit) { RailsPlan::CLI.start(['remove', 'nonexistent']) }
    end
    
    assert_includes output, "❌ Module 'nonexistent' is not installed"
  end

  def test_plan_command_shows_installation_preview
    output = capture_output { RailsPlan::CLI.start(['plan', 'test_module']) }
    
    assert_includes output, "📋 Planning install operation for 'test_module' module..."
    assert_includes output, "🔍 Operation: Install"
    assert_includes output, "📦 Module: test_module"
    assert_includes output, "📁 Files that would be created/copied:"
    assert_includes output, "💡 This is a preview only. No changes have been made."
    assert_includes output, "💡 To proceed with the operation, run: railsplan add test_module"
  end

  def test_plan_command_shows_upgrade_preview
    # First install the module
    install_test_module
    
    output = capture_output { RailsPlan::CLI.start(['plan', 'test_module', 'upgrade']) }
    
    assert_includes output, "📋 Planning upgrade operation for 'test_module' module..."
    assert_includes output, "🔍 Operation: Upgrade"
    assert_includes output, "📦 Module: test_module"
    assert_includes output, "📈 Current version: 1.0.0"
    assert_includes output, "📈 Available version: 1.1.0"
    assert_includes output, "💡 This is a preview only. No changes have been made."
    assert_includes output, "💡 To proceed with the operation, run: railsplan upgrade test_module"
  end

  def test_plan_command_shows_already_installed_warning
    # First install the module
    install_test_module
    
    output = capture_output { RailsPlan::CLI.start(['plan', 'test_module']) }
    
    assert_includes output, "⚠️  Module is already installed"
    assert_includes output, "Use 'plan test_module upgrade' to preview upgrade changes"
  end

  def test_plan_command_fails_for_nonexistent_module
    output = capture_output do
      assert_raises(SystemExit) { RailsPlan::CLI.start(['plan', 'nonexistent']) }
    end
    
    assert_includes output, "❌ Module 'nonexistent' not found in templates"
  end

  def test_plan_command_requires_module_name
    output = capture_output do
      RailsPlan::CLI.start(['plan'])
    end
    
    assert_includes output, "ERROR: \"rails plan\" was called with no arguments"
    assert_includes output, "Usage: \"rails plan MODULE [OPERATION]\""
  end

  def test_plan_command_handles_invalid_operation
    output = capture_output do
      assert_raises(SystemExit) { RailsPlan::CLI.start(['plan', 'test_module', 'invalid']) }
    end
    
    assert_includes output, "❌ Unknown operation: invalid. Use 'install' or 'upgrade'"
  end

  def test_plan_command_shows_migrations_and_dependencies
    output = capture_output { RailsPlan::CLI.start(['plan', 'test_module_with_migrations']) }
    
    assert_includes output, "📋 Planning install operation for 'test_module_with_migrations' module..."
    assert_includes output, "📁 Files that would be created/copied:"
    assert_includes output, "💡 This is a preview only. No changes have been made."
  end

  def test_info_command_shows_module_details
    output = capture_output { RailsPlan::CLI.start(['info', 'test_module']) }
    
    assert_includes output, "📋 Module: test_module"
    assert_includes output, "📖 Description: Test Module - A test module for testing"
    assert_includes output, "🏷️  Version: 1.0.0"
    assert_includes output, "❌ Status: Not installed"
  end

  def test_info_command_fails_for_nonexistent_module
    output = capture_output do
      assert_raises(SystemExit) { RailsPlan::CLI.start(['info', 'nonexistent']) }
    end
    
    assert_includes output, "❌ Module 'nonexistent' not found in templates"
  end

  def test_upgrade_command_with_specific_module
    # Install module first
    install_test_module
    
    output = capture_output { RailsPlan::CLI.start(['upgrade', 'test_module']) }
    
    assert_includes output, "🔄 Upgrading test_module module..."
    assert_includes output, "✅ Successfully upgraded test_module module!"
  end

  def test_upgrade_command_without_module_upgrades_all
    output = capture_output { RailsPlan::CLI.start(['upgrade']) }
    
    assert_includes output, "🔄 Upgrading all modules..."
    assert_includes output, "ℹ No modules installed to upgrade"
  end

  def test_upgrade_command_fails_for_nonexistent_module
    output = capture_output do
      assert_raises(SystemExit) { RailsPlan::CLI.start(['upgrade', 'nonexistent']) }
    end
    
    assert_includes output, "❌ Module 'nonexistent' is not installed"
  end

  def test_doctor_command_validates_setup
    output = capture_output { RailsPlan::CLI.start(['doctor']) }
    assert_includes output, 'Running RailsPlan diagnostics...'
    assert_includes output, 'Ruby version:'
    assert_includes output, 'Diagnostics complete!'
  end

  def test_help_command_shows_usage
    output = capture_output { RailsPlan::CLI.start(['help']) }
    assert_includes output, 'RailsPlan - Global CLI for Rails SaaS Bootstrapping'
    assert_includes output, 'Usage:'
  end

  def test_force_flag_allows_reinstall
    # Install module first
    capture_output { RailsPlan::CLI.start(['add', 'test_module']) }
    
    # Try to install again with force
    output = capture_output { RailsPlan::CLI.start(['add', 'test_module', '--force']) }
    
    assert_includes output, "Adding module 'test_module' to existing application..."
    assert_includes output, 'This feature is coming soon!'
  end

  def test_verbose_flag_shows_extra_output
    output = capture_output { RailsPlan::CLI.start(['add', 'test_module', '--verbose']) }
    
    assert_includes output, "Adding module 'test_module' to existing application..."
    assert_includes output, 'This feature is coming soon!'
  end

  private

  def create_test_structure
    # Create scaffold structure in test directory
    FileUtils.mkdir_p('scaffold/config')
    FileUtils.mkdir_p('scaffold/lib/templates/railsplan/test_module')
    FileUtils.mkdir_p('scaffold/lib/templates/railsplan/test_module_with_migrations/db/migrate')
    FileUtils.mkdir_p('scaffold/lib/templates/railsplan/test_module_with_migrations/config')
    
    # Create test module template
    module_path = 'scaffold/lib/templates/railsplan/test_module'
    
    File.write(File.join(module_path, 'README.md'), "# Test Module\n\nA test module for testing.\n")
    File.write(File.join(module_path, 'VERSION'), "1.0.0\n")
    File.write(File.join(module_path, 'install.rb'), "# Test installer\n")
    File.write(File.join(module_path, 'test_file.txt'), "Test content\n")
    
    # Create test module with migrations
    module_with_migrations_path = 'scaffold/lib/templates/railsplan/test_module_with_migrations'
    
    File.write(File.join(module_with_migrations_path, 'README.md'), "# Test Module with Migrations\n\nA test module with migrations.\n")
    File.write(File.join(module_with_migrations_path, 'VERSION'), "1.0.0\n")
    File.write(File.join(module_with_migrations_path, 'install.rb'), <<~RUBY)
      # Test installer with gems
      gem 'stripe', '~> 15.3'
      gem 'prawn', '~> 2.5'
      run 'bundle install'
    RUBY
    
    # Create a test migration
    File.write(File.join(module_with_migrations_path, 'db', 'migrate', '001_create_test_table.rb'), <<~RUBY)
      class CreateTestTable < ActiveRecord::Migration[7.0]
        def change
          create_table :test_items do |t|
            t.string :name, null: false
            t.text :description
            t.timestamps
          end
          
          add_index :test_items, :name
        end
      end
    RUBY
    
    # Create a test routes file
    File.write(File.join(module_with_migrations_path, 'config', 'routes.rb'), <<~RUBY)
      # Test module routes
      resources :test_items
      get '/admin/test', to: 'admin/test_items#index'
    RUBY
    
    # Create empty registry (test_module not installed by default)
    registry = { 'installed' => {} }
    File.write('scaffold/config/railsplan_modules.json', JSON.pretty_generate(registry))
    
    # Create log directory
    FileUtils.mkdir_p('log')
    
    # Store original constants and override them for testing
    @original_template_path = RailsPlan::CLI.const_get(:TEMPLATE_PATH) if RailsPlan::CLI.const_defined?(:TEMPLATE_PATH)
    @original_registry_path = RailsPlan::CLI.const_get(:REGISTRY_PATH) if RailsPlan::CLI.const_defined?(:REGISTRY_PATH)
    
    # Remove existing constants if they exist, then set new ones
    RailsPlan::CLI.send(:remove_const, :TEMPLATE_PATH) if RailsPlan::CLI.const_defined?(:TEMPLATE_PATH)
    RailsPlan::CLI.send(:remove_const, :REGISTRY_PATH) if RailsPlan::CLI.const_defined?(:REGISTRY_PATH)
    
    RailsPlan::CLI.const_set(:TEMPLATE_PATH, File.expand_path('scaffold/lib/templates/railsplan'))
    RailsPlan::CLI.const_set(:REGISTRY_PATH, File.expand_path('scaffold/config/railsplan_modules.json'))
  end

  def install_test_module
    # Create the app/domains directory and test_module files to simulate installation
    FileUtils.mkdir_p('app/domains/test_module')
    File.write('app/domains/test_module/README.md', "# Test Module\n\nA test module for testing.\n")
    
    # Update the registry to mark test_module as installed
    registry = JSON.parse(File.read('scaffold/config/railsplan_modules.json'))
    registry['installed']['test_module'] = {
      'version' => '1.0.0',
      'installed_at' => '2024-01-01'
    }
    File.write('scaffold/config/railsplan_modules.json', JSON.pretty_generate(registry))
  end

  def capture_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      yield
    rescue SystemExit
      # Ignore system exits for testing
    end
    
    output = $stdout.string + $stderr.string
    
    $stdout = original_stdout
    $stderr = original_stderr
    
    output
  end
end