# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'

class RailsPlanCLIIntegrationTest < Minitest::Test
  def setup
    @railsplan_path = File.expand_path('../bin/railsplan', __dir__)
    @project_root = File.expand_path('..', __dir__)
  end

  def test_help_command
    output, status = run_railsplan(['help'])
    
    assert status.success?
    assert_includes output, 'bin/railsplan - Rails SaaS Starter Template Module Manager'
    assert_includes output, 'USAGE:'
    assert_includes output, 'list'
    assert_includes output, 'add MODULE'
    assert_includes output, 'remove MODULE'
  end

  def test_list_command
    output, status = run_railsplan(['list'])
    
    assert status.success?
    assert_includes output, '📦 Available modules:'
    assert_includes output, '🔧 Installed modules:'
    # Should show available modules from scaffold/lib/templates/railsplan
    assert_includes output, 'billing'
    assert_includes output, 'ai'
  end

  def test_doctor_command
    output, status = run_railsplan(['doctor'])
    
    assert status.success?
    assert_includes output, '🏥 Running system diagnostics...'
    assert_includes output, 'Ruby version:'
    assert_includes output, '✅ Module registry found'
    assert_includes output, '✅ Module templates directory found'
  end

  def test_info_command_for_existing_module
    output, status = run_railsplan(['info', 'billing'])
    
    assert status.success?
    assert_includes output, '📋 Module: billing'
    assert_includes output, '📖 Description:'
    assert_includes output, 'Billing Module'
    assert_includes output, '🏷️  Version:'
  end

  def test_info_command_for_nonexistent_module
    output, status = run_railsplan(['info', 'nonexistent_module'])
    
    refute status.success?
    assert_includes output, "❌ Module 'nonexistent_module' not found"
  end

  def test_add_nonexistent_module
    output, status = run_railsplan(['add', 'nonexistent_module'])
    
    refute status.success?
    assert_includes output, "❌ Module 'nonexistent_module' not found in templates"
  end

  def test_remove_uninstalled_module
    output, status = run_railsplan(['remove', 'some_module'])
    
    refute status.success?
    assert_includes output, "❌ Module 'some_module' is not installed"
  end

  def test_invalid_command
    output, status = run_railsplan(['invalid_command'])
    
    refute status.success?
    assert_includes output, "❌ Unknown command: invalid_command"
  end

  def test_missing_module_argument_for_add
    output, status = run_railsplan(['add'])
    
    refute status.success?
    assert_includes output, "❌ Module name required. Usage: bin/railsplan add MODULE_NAME"
  end

  def test_missing_module_argument_for_remove
    output, status = run_railsplan(['remove'])
    
    refute status.success?
    assert_includes output, "❌ Module name required. Usage: bin/railsplan remove MODULE_NAME"
  end

  def test_missing_module_argument_for_info
    output, status = run_railsplan(['info'])
    
    refute status.success?
    assert_includes output, "❌ Module name required. Usage: bin/railsplan info MODULE_NAME"
  end

  private

  def run_railsplan(args)
    Dir.chdir(@project_root) do
      output, status = Open3.capture2e(@railsplan_path, *args)
      [output, status]
    end
  end
end