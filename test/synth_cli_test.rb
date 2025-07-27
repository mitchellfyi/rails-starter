# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'json'
require 'stringio'

# Load the CLI class directly
synth_cli_file = File.read(File.expand_path('../bin/synth', __dir__))
# Remove the auto-start line and eval the class definition
synth_cli_code = synth_cli_file.gsub(/^# Start the CLI.*$/m, '')
eval(synth_cli_code)

class SynthCLITest < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @test_dir = Dir.mktmpdir('synth_test')
    Dir.chdir(@test_dir)
    
    # Create test structure
    create_test_structure
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_list_command_shows_available_modules
    output = capture_output { SynthCLI.start(['list']) }
    
    assert_includes output, '📦 Available modules:'
    assert_includes output, 'test_module'
    assert_includes output, '🔧 Installed modules:'
  end

  def test_add_command_installs_module
    output = capture_output { SynthCLI.start(['add', 'test_module']) }
    
    assert_includes output, '📦 Installing test_module module...'
    assert_includes output, '✅ Successfully installed test_module module!'
    
    # Check files were created
    assert Dir.exist?('app/domains/test_module')
    assert File.exist?('app/domains/test_module/README.md')
    
    # Check registry was updated
    registry = JSON.parse(File.read('scaffold/config/synth_modules.json'))
    assert registry.dig('installed', 'test_module')
  end

  def test_add_command_fails_for_nonexistent_module
    output = capture_output do
      assert_raises(SystemExit) { SynthCLI.start(['add', 'nonexistent']) }
    end
    
    assert_includes output, "❌ Module 'nonexistent' not found in templates"
  end

  def test_remove_command_uninstalls_module
    # First install the module
    capture_output { SynthCLI.start(['add', 'test_module']) }
    
    # Then remove it
    output = capture_output { SynthCLI.start(['remove', 'test_module', '--force']) }
    
    assert_includes output, '🗑️  Removing test_module module...'
    assert_includes output, '✅ Successfully removed test_module module!'
    
    # Check files were removed
    refute Dir.exist?('app/domains/test_module')
    
    # Check registry was updated
    registry = JSON.parse(File.read('scaffold/config/synth_modules.json'))
    refute registry.dig('installed', 'test_module')
  end

  def test_info_command_shows_module_details
    output = capture_output { SynthCLI.start(['info', 'test_module']) }
    
    assert_includes output, '📋 Module: test_module'
    assert_includes output, '📖 Description:'
    assert_includes output, 'Test Module'
    assert_includes output, '🏷️  Version: 1.0.0'
    assert_includes output, '❌ Status: Not installed'
  end

  def test_doctor_command_validates_setup
    output = capture_output { SynthCLI.start(['doctor']) }
    
    assert_includes output, '🏥 Running system diagnostics...'
    assert_includes output, 'Ruby version:'
    assert_includes output, '✅ Module registry found'
    assert_includes output, '✅ Module templates directory found'
    assert_includes output, '🏥 Diagnostics complete'
  end

  def test_help_command_shows_usage
    output = capture_output { SynthCLI.start(['help']) }
    
    assert_includes output, 'bin/synth - Rails SaaS Starter Template Module Manager'
    assert_includes output, 'USAGE:'
    assert_includes output, 'COMMANDS:'
    assert_includes output, 'list'
    assert_includes output, 'add MODULE'
    assert_includes output, 'remove MODULE'
  end

  def test_upgrade_command_with_specific_module
    # Install module first
    capture_output { SynthCLI.start(['add', 'test_module']) }
    
    output = capture_output { SynthCLI.start(['upgrade', 'test_module']) }
    
    assert_includes output, '🔄 Upgrading test_module module...'
    assert_includes output, '✅ Successfully installed test_module module!'
  end

  def test_force_flag_allows_reinstall
    # Install module first
    capture_output { SynthCLI.start(['add', 'test_module']) }
    
    # Try to install again with force
    output = capture_output { SynthCLI.start(['add', 'test_module', '--force']) }
    
    assert_includes output, '✅ Successfully installed test_module module!'
  end

  def test_verbose_flag_shows_extra_output
    output = capture_output { SynthCLI.start(['add', 'test_module', '--verbose']) }
    
    assert_includes output, 'Copied README.md'
  end

  def test_doctor_command_runs_diagnostics
    output = capture_output { SynthCLI.start(['doctor']) }
    
    assert_includes output, '🏥 Running system diagnostics...'
    assert_includes output, 'Ruby version:'
    assert_includes output, 'Checking template structure:'
    assert_includes output, 'Checking environment variables:'
    assert_includes output, 'Checking API key configuration:'
    assert_includes output, 'Checking database migrations:'
    assert_includes output, 'Checking installed module integrity:'
    assert_includes output, '🏥 Diagnostics complete'
  end

  private

  def create_test_structure
    # Create scaffold structure in test directory
    FileUtils.mkdir_p('scaffold/config')
    FileUtils.mkdir_p('scaffold/lib/templates/synth/test_module')
    
    # Create test module template
    module_path = 'scaffold/lib/templates/synth/test_module'
    
    File.write(File.join(module_path, 'README.md'), "# Test Module\n\nA test module for testing.\n")
    File.write(File.join(module_path, 'VERSION'), "1.0.0\n")
    File.write(File.join(module_path, 'install.rb'), "# Test installer\n")
    File.write(File.join(module_path, 'test_file.txt'), "Test content\n")
    
    # Create empty registry
    registry = { 'installed' => {} }
    File.write('scaffold/config/synth_modules.json', JSON.pretty_generate(registry))
    
    # Create log directory
    FileUtils.mkdir_p('log')
    
    # Override the CLI constants to point to our test directories
    SynthCLI.const_set(:TEMPLATE_PATH, File.expand_path('scaffold/lib/templates/synth'))
    SynthCLI.const_set(:REGISTRY_PATH, File.expand_path('scaffold/config/synth_modules.json'))
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