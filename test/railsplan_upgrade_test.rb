# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'json'
require 'stringio'

# Load the CLI class directly
railsplan_cli_file = File.read(File.expand_path('../bin/railsplan', __dir__))
# Remove the auto-start line and eval the class definition
railsplan_cli_code = railsplan_cli_file.gsub(/^# Start the CLI.*$/m, '')
eval(railsplan_cli_code)

class RailsPlanUpgradeTest < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @test_dir = Dir.mktmpdir('railsplan_upgrade_test')
    Dir.chdir(@test_dir)
    
    # Create test structure
    create_test_structure
    
    # Override ARGV to prevent conflicts
    @original_argv = ARGV.dup
    ARGV.clear
  end

  def teardown
    ARGV.replace(@original_argv)
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_upgrade_detects_version_differences
    # Install v1.0.0 of test module
    install_test_module('1.0.0')
    
    # Update template to v1.1.0
    update_template_version('test_module', '1.1.0')
    
    output = capture_output { RailsPlanCLI.start(['upgrade', 'test_module', '--yes']) }
    
    assert_includes output, 'Upgrading test_module from v1.0.0 to v1.1.0'
    assert_includes output, 'Successfully upgraded test_module to v1.1.0!'
    
    # Verify registry was updated
    registry = JSON.parse(File.read('scaffold/config/railsplan_modules.json'))
    assert_equal '1.1.0', registry.dig('installed', 'test_module', 'version')
    assert_equal '1.0.0', registry.dig('installed', 'test_module', 'previous_version')
  end

  def test_upgrade_skips_up_to_date_modules
    # Install v1.0.0 and keep template at same version
    install_test_module('1.0.0')
    
    output = capture_output { RailsPlanCLI.start(['upgrade', 'test_module']) }
    
    assert_includes output, "Module 'test_module' is already up to date (v1.0.0)"
  end

  def test_upgrade_creates_backup_by_default
    install_test_module('1.0.0')
    update_template_version('test_module', '1.1.0')
    
    capture_output { RailsPlanCLI.start(['upgrade', 'test_module', '--yes', '--verbose']) }
    
    # Check backup was created
    backup_dirs = Dir.glob('backups/railsplan_modules/test_module_v1.0.0_*')
    assert backup_dirs.length > 0, "Expected backup directory to be created"
    
    backup_dir = backup_dirs.first
    assert Dir.exist?(File.join(backup_dir, 'app_domains')), "Expected app_domains backup"
    assert File.exist?(File.join(backup_dir, 'registry.json')), "Expected registry backup"
  end

  def test_upgrade_skips_backup_with_flag
    install_test_module('1.0.0')
    update_template_version('test_module', '1.1.0')
    
    # Set ARGV to include the --no-backup flag
    ARGV.replace(['upgrade', 'test_module', '--yes', '--no-backup'])
    
    capture_output { RailsPlanCLI.start(['upgrade', 'test_module', '--yes', '--no-backup']) }
    
    # Check no backup was created
    backup_dirs = Dir.glob('backups/railsplan_modules/test_module_v1.0.0_*')
    assert_equal 0, backup_dirs.length, "Expected no backup directory with --no-backup flag"
  end

  def test_upgrade_all_finds_upgradeable_modules
    # Install multiple modules at different versions
    install_test_module('1.0.0')
    install_another_test_module('1.0.0')
    
    # Update template versions
    update_template_version('test_module', '1.1.0')
    update_template_version('another_module', '1.2.0')
    
    # Set ARGV to include the --yes flag
    ARGV.replace(['upgrade', '--yes'])
    
    output = capture_output { RailsPlanCLI.start(['upgrade', '--yes']) }
    
    assert_includes output, 'Found 2 module(s) to upgrade:'
    assert_includes output, 'test_module: v1.0.0 -> v1.1.0'
    assert_includes output, 'another_module: v1.0.0 -> v1.2.0'
  end

  def test_upgrade_all_skips_when_all_up_to_date
    install_test_module('1.0.0')
    
    output = capture_output { RailsPlanCLI.start(['upgrade']) }
    
    assert_includes output, 'All installed modules are up to date'
  end

  def test_version_compare_correctly_orders_versions
    cli = RailsPlanCLI.new
    
    assert_equal 1, cli.send(:version_compare, '1.1.0', '1.0.0')
    assert_equal -1, cli.send(:version_compare, '1.0.0', '1.1.0')
    assert_equal 0, cli.send(:version_compare, '1.0.0', '1.0.0')
    assert_equal 1, cli.send(:version_compare, '2.0.0', '1.9.9')
    assert_equal 1, cli.send(:version_compare, '1.0.1', '1.0.0')
  end

  def test_conflict_detection_finds_modified_files
    install_test_module('1.0.0')
    
    # Modify an installed file
    test_file = 'app/domains/test_module/test_file.txt'
    File.write(test_file, "Modified content\n")
    
    # Update template with different content
    template_file = 'scaffold/lib/templates/railsplan/test_module/test_file.txt'
    File.write(template_file, "Updated template content\n")
    update_template_version('test_module', '1.1.0')
    
    cli = RailsPlanCLI.new
    conflicts = cli.send(:detect_conflicts, 'test_module', 'scaffold/lib/templates/railsplan/test_module')
    
    assert_equal 1, conflicts.length
    assert_equal 'test_file.txt', conflicts.first[:file]
  end

  def test_migration_handling_copies_new_migrations
    install_test_module('1.0.0')
    
    # Add a migration to the template
    migration_dir = 'scaffold/lib/templates/railsplan/test_module/db/migrate'
    FileUtils.mkdir_p(migration_dir)
    File.write(File.join(migration_dir, '20240101000000_add_test_table.rb'), <<~RUBY)
      class AddTestTable < ActiveRecord::Migration[7.0]
        def change
          create_table :test_table do |t|
            t.string :name
            t.timestamps
          end
        end
      end
    RUBY
    
    update_template_version('test_module', '1.1.0')
    
    capture_output { RailsPlanCLI.start(['upgrade', 'test_module', '--yes', '--verbose']) }
    
    # Check migration was copied
    assert File.exist?('db/migrate/20240101000000_add_test_table.rb')
  end

  private

  def create_test_structure
    # Create scaffold structure
    FileUtils.mkdir_p('scaffold/config')
    FileUtils.mkdir_p('scaffold/lib/templates/railsplan/test_module')
    FileUtils.mkdir_p('scaffold/lib/templates/railsplan/another_module')
    
    # Create test module template
    create_module_template('test_module', '1.0.0')
    create_module_template('another_module', '1.0.0')
    
    # Create empty registry
    registry = { 'installed' => {} }
    File.write('scaffold/config/railsplan_modules.json', JSON.pretty_generate(registry))
    
    # Create necessary directories
    FileUtils.mkdir_p('log')
    FileUtils.mkdir_p('app/domains')
    FileUtils.mkdir_p('db/migrate')
    
    # Override CLI constants
    RailsPlanCLI.const_set(:TEMPLATE_PATH, File.expand_path('scaffold/lib/templates/railsplan'))
    RailsPlanCLI.const_set(:REGISTRY_PATH, File.expand_path('scaffold/config/railsplan_modules.json'))
  end

  def create_module_template(module_name, version)
    module_path = "scaffold/lib/templates/railsplan/#{module_name}"
    FileUtils.mkdir_p(module_path)
    
    File.write(File.join(module_path, 'README.md'), "# #{module_name.capitalize} Module\n\nA test module.\n")
    File.write(File.join(module_path, 'VERSION'), "#{version}\n")
    File.write(File.join(module_path, 'install.rb'), "# Test installer\n")
    File.write(File.join(module_path, 'test_file.txt'), "Test content\n")
  end

  def install_test_module(version)
    update_template_version('test_module', version)
    capture_output { RailsPlanCLI.start(['add', 'test_module']) }
  end

  def install_another_test_module(version)
    update_template_version('another_module', version)
    capture_output { RailsPlanCLI.start(['add', 'another_module']) }
  end

  def update_template_version(module_name, version)
    version_file = "scaffold/lib/templates/railsplan/#{module_name}/VERSION"
    File.write(version_file, "#{version}\n")
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