# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'json'
require 'stringio'

class InitModuleTest < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @test_dir = Dir.mktmpdir('synth_init_module_test')
    Dir.chdir(@test_dir)
    
    # Create test structure
    create_test_structure
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_init_module_command_requires_module_name
    output = capture_output { run_synth_command(['init-module']) }
    
    assert_includes output, '❌ Module name required. Usage: bin/synth init-module MODULE_NAME'
  end

  def test_init_module_validates_module_name
    output = capture_output { run_synth_command(['init-module', 'Invalid-Name']) }
    
    assert_includes output, '❌ Invalid module name \'Invalid-Name\''
    assert_includes output, 'Module names must be lowercase, alphanumeric, and may contain underscores or hyphens'
  end

  def test_init_module_creates_complete_module_structure
    output = capture_output { run_synth_command(['init-module', 'my_feature']) }
    
    assert_includes output, '🚀 Generating new module: my_feature'
    assert_includes output, '✅ Successfully generated module template'
    
    module_path = File.join('scaffold', 'lib', 'templates', 'synth', 'my_feature')
    
    # Check basic files
    assert File.exist?(File.join(module_path, 'README.md'))
    assert File.exist?(File.join(module_path, 'VERSION'))
    assert File.exist?(File.join(module_path, 'install.rb'))
    assert File.exist?(File.join(module_path, 'remove.rb'))
    
    # Check directory structure
    assert Dir.exist?(File.join(module_path, 'app'))
    assert Dir.exist?(File.join(module_path, 'app', 'controllers'))
    assert Dir.exist?(File.join(module_path, 'app', 'models'))
    assert Dir.exist?(File.join(module_path, 'app', 'views'))
    assert Dir.exist?(File.join(module_path, 'app', 'services'))
    assert Dir.exist?(File.join(module_path, 'config'))
    assert Dir.exist?(File.join(module_path, 'db', 'migrate'))
    assert Dir.exist?(File.join(module_path, 'test'))
    assert Dir.exist?(File.join(module_path, 'spec'))
    
    # Check app files
    assert File.exist?(File.join(module_path, 'app', 'controllers', 'my_feature_controller.rb'))
    assert File.exist?(File.join(module_path, 'app', 'models', 'my_feature_item.rb'))
    assert File.exist?(File.join(module_path, 'app', 'services', 'my_feature_service.rb'))
    
    # Check migration
    assert File.exist?(File.join(module_path, 'db', 'migrate', 'create_my_feature_items.rb'))
    
    # Check test files
    assert File.exist?(File.join(module_path, 'test', 'controllers', 'my_feature_controller_test.rb'))
    assert File.exist?(File.join(module_path, 'test', 'models', 'my_feature_item_test.rb'))
    assert File.exist?(File.join(module_path, 'test', 'services', 'my_feature_service_test.rb'))
    assert File.exist?(File.join(module_path, 'test', 'integration', 'my_feature_integration_test.rb'))
    assert File.exist?(File.join(module_path, 'test', 'fixtures', 'my_feature_items.yml'))
    
    # Check spec files
    assert File.exist?(File.join(module_path, 'spec', 'controllers', 'my_feature_controller_spec.rb'))
    assert File.exist?(File.join(module_path, 'spec', 'models', 'my_feature_item_spec.rb'))
    assert File.exist?(File.join(module_path, 'spec', 'services', 'my_feature_service_spec.rb'))
    assert File.exist?(File.join(module_path, 'spec', 'requests', 'my_feature_spec.rb'))
    assert File.exist?(File.join(module_path, 'spec', 'factories', 'my_feature_items.rb'))
    
    # Check config files
    assert File.exist?(File.join(module_path, 'config', 'routes.rb'))
    assert File.exist?(File.join(module_path, 'config', 'initializers', 'my_feature.rb'))
  end

  def test_init_module_creates_valid_content
    capture_output { run_synth_command(['init-module', 'test_module']) }
    
    module_path = File.join('scaffold', 'lib', 'templates', 'synth', 'test_module')
    
    # Check VERSION file
    version_content = File.read(File.join(module_path, 'VERSION'))
    assert_equal "1.0.0\n", version_content
    
    # Check README content
    readme_content = File.read(File.join(module_path, 'README.md'))
    assert_includes readme_content, '# TestModule Module'
    assert_includes readme_content, 'bin/synth add test_module'
    
    # Check install script content
    install_content = File.read(File.join(module_path, 'install.rb'))
    assert_includes install_content, 'TestModule module installer'
    assert_includes install_content, 'say_status :test_module'
    assert_includes install_content, 'config.test_module'
    
    # Check controller content
    controller_content = File.read(File.join(module_path, 'app', 'controllers', 'test_module_controller.rb'))
    assert_includes controller_content, 'class TestModuleController'
    assert_includes controller_content, 'before_action :authenticate_user!'
    
    # Check model content
    model_content = File.read(File.join(module_path, 'app', 'models', 'test_module_item.rb'))
    assert_includes model_content, 'class TestModuleItem'
    assert_includes model_content, 'belongs_to :user'
    assert_includes model_content, 'validates :name, presence: true'
    
    # Check migration content
    migration_content = File.read(File.join(module_path, 'db', 'migrate', 'create_test_module_items.rb'))
    assert_includes migration_content, 'class CreateTestModuleItems'
    assert_includes migration_content, 'create_table :test_module_items'
    assert_includes migration_content, 't.references :user'
  end

  def test_init_module_prevents_overwrite_without_force
    # Create initial module
    capture_output { run_synth_command(['init-module', 'existing_module']) }
    
    # Try to create again without force
    output = capture_output { run_synth_command(['init-module', 'existing_module']) }
    
    assert_includes output, '❌ Module \'existing_module\' already exists'
    assert_includes output, 'Use --force to overwrite existing module'
  end

  def test_init_module_allows_overwrite_with_force
    # Create initial module
    capture_output { run_synth_command(['init-module', 'overwrite_test']) }
    
    module_path = File.join('scaffold', 'lib', 'templates', 'synth', 'overwrite_test')
    
    # Modify a file to test overwrite
    File.write(File.join(module_path, 'VERSION'), "0.5.0\n")
    
    # Overwrite with force - Set ARGV for force detection
    original_argv = ARGV.dup
    ARGV.replace(['init-module', 'overwrite_test', '--force'])
    
    output = capture_output { run_synth_command(['init-module', 'overwrite_test', '--force']) }
    
    ARGV.replace(original_argv)
    
    assert_includes output, '✅ Successfully generated module template'
    
    # Check that file was overwritten
    version_content = File.read(File.join(module_path, 'VERSION'))
    assert_equal "1.0.0\n", version_content
  end

  def test_init_module_handles_hyphenated_names
    capture_output { run_synth_command(['init-module', 'my-feature']) }
    
    module_path = File.join('scaffold', 'lib', 'templates', 'synth', 'my-feature')
    
    # Check that files are created
    assert File.exist?(File.join(module_path, 'README.md'))
    assert File.exist?(File.join(module_path, 'app', 'controllers', 'my-feature_controller.rb'))
    
    # Check class name generation
    controller_content = File.read(File.join(module_path, 'app', 'controllers', 'my-feature_controller.rb'))
    assert_includes controller_content, 'class MyFeatureController'
    
    readme_content = File.read(File.join(module_path, 'README.md'))
    assert_includes readme_content, '# MyFeature Module'
  end

  def test_init_module_handles_underscored_names
    capture_output { run_synth_command(['init-module', 'my_feature_test']) }
    
    module_path = File.join('scaffold', 'lib', 'templates', 'synth', 'my_feature_test')
    
    # Check that files are created
    assert File.exist?(File.join(module_path, 'README.md'))
    assert File.exist?(File.join(module_path, 'app', 'controllers', 'my_feature_test_controller.rb'))
    
    # Check class name generation
    controller_content = File.read(File.join(module_path, 'app', 'controllers', 'my_feature_test_controller.rb'))
    assert_includes controller_content, 'class MyFeatureTestController'
    
    readme_content = File.read(File.join(module_path, 'README.md'))
    assert_includes readme_content, '# MyFeatureTest Module'
  end

  def test_module_appears_in_list_after_creation
    # Create module
    capture_output { run_synth_command(['init-module', 'list_test']) }
    
    # Check it appears in list
    output = capture_output { run_synth_command(['list']) }
    
    assert_includes output, 'list_test'
    assert_includes output, 'v1.0.0'
  end

  private

  def create_test_structure
    # Create the scaffold directory structure
    FileUtils.mkdir_p('scaffold/lib/templates/synth')
    FileUtils.mkdir_p('scaffold/config')
    
    # Create a simple registry file
    registry = { 'installed' => {} }
    File.write('scaffold/config/synth_modules.json', JSON.pretty_generate(registry))
    
    # Create a simple module for testing
    test_module_path = 'scaffold/lib/templates/synth/existing_test_module'
    FileUtils.mkdir_p(test_module_path)
    File.write(File.join(test_module_path, 'README.md'), "# Test Module\n")
    File.write(File.join(test_module_path, 'VERSION'), "1.0.0\n")
  end

  def run_synth_command(args)
    # Create a custom CLI class for each test to avoid constant redefinition issues
    cli_code = create_test_cli_class
    eval(cli_code)
    
    TestSynthCLI.start(args)
  end

  def create_test_cli_class
    template_path = File.expand_path('scaffold/lib/templates/synth')
    registry_path = File.expand_path('scaffold/config/synth_modules.json')
    
    # Load the original CLI code and modify it for testing
    synth_cli_file = File.read(File.expand_path('../bin/synth', __dir__))
    
    # Remove the auto-start line and replace class name and constants
    cli_code = synth_cli_file
      .gsub(/^# Start the CLI.*$/m, '')
      .gsub('class SynthCLI', 'class TestSynthCLI')
      .gsub("TEMPLATE_PATH = File.expand_path('../scaffold/lib/templates/synth', __dir__)", 
            "TEMPLATE_PATH = '#{template_path}'")
      .gsub("REGISTRY_PATH = File.expand_path('../scaffold/config/synth_modules.json', __dir__)", 
            "REGISTRY_PATH = '#{registry_path}'")
    
    cli_code
  end

  def capture_output
    original_stdout = $stdout
    original_stderr = $stderr
    
    fake_stdout = StringIO.new
    fake_stderr = StringIO.new
    
    $stdout = fake_stdout
    $stderr = fake_stderr
    
    begin
      yield
    rescue SystemExit
      # Ignore exit calls in tests
    end
    
    fake_stdout.string + fake_stderr.string
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end