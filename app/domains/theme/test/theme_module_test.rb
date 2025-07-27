# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'

class ThemeModuleTest < Minitest::Test
  def setup
    @test_dir = Dir.mktmpdir('theme_test')
    @original_dir = Dir.pwd
    Dir.chdir(@test_dir)
    
    # Create a minimal Rails app structure for testing
    FileUtils.mkdir_p('app/assets/stylesheets')
    FileUtils.mkdir_p('app/assets/images')
    FileUtils.mkdir_p('app/views/shared')
    FileUtils.mkdir_p('app/javascript/controllers')
    FileUtils.mkdir_p('config/initializers')
    
    # Create a minimal Rails class structure
    File.write('config/application.rb', <<~RUBY)
      class TestApp
        def self.module_parent_name
          'TestApp'
        end
      end
      
      module Rails
        def self.application
          @application ||= TestApp.new
        end
        
        class << self.application
          def class
            TestApp
          end
          
          def configure
            yield(self) if block_given?
          end
          
          def config
            @config ||= OpenStruct.new
          end
        end
      end
    RUBY
    
    require_relative './test_helpers'
  end
  
  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir)
  end
  
  def test_theme_module_files_exist
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    assert File.exist?(install_path), 'Theme install.rb file should exist'
    
    readme_path = File.join(theme_dir, 'README.md')
    assert File.exist?(readme_path), 'Theme README.md file should exist'
    
    version_path = File.join(theme_dir, 'VERSION')
    assert File.exist?(version_path), 'Theme VERSION file should exist'
  end
  
  def test_theme_css_variables_structure
    # Simulate running the install script
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    assert File.exist?('app/assets/stylesheets/_theme_variables.css'), 
           'Theme variables CSS file should be created'
    
    variables_content = File.read('app/assets/stylesheets/_theme_variables.css')
    
    # Check for essential CSS custom properties
    assert_includes variables_content, '--brand-primary:', 'Should include brand primary color'
    assert_includes variables_content, '--text-primary:', 'Should include text primary color'
    assert_includes variables_content, '--bg-primary:', 'Should include background primary color'
    assert_includes variables_content, '--font-sans:', 'Should include font family variables'
    assert_includes variables_content, '[data-theme="dark"]', 'Should include dark theme support'
    assert_includes variables_content, 'prefers-color-scheme: dark', 'Should include system theme detection'
  end
  
  def test_theme_override_file_creation
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    assert File.exist?('app/assets/stylesheets/theme.css'), 
           'Theme override CSS file should be created'
    
    theme_content = File.read('app/assets/stylesheets/theme.css')
    assert_includes theme_content, 'Theme Customization Override File', 
                    'Should include customization instructions'
    assert_includes theme_content, '.btn-primary', 'Should include example component styles'
  end
  
  def test_theme_components_creation
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    # Check theme switcher component
    assert File.exist?('app/views/shared/_theme_switcher.html.erb'),
           'Theme switcher component should be created'
    
    switcher_content = File.read('app/views/shared/_theme_switcher.html.erb')
    assert_includes switcher_content, 'data-controller="theme-switcher"',
                    'Should include Stimulus controller'
    assert_includes switcher_content, 'value="system"', 'Should include system option'
    
    # Check brand logo component
    assert File.exist?('app/views/shared/_brand_logo.html.erb'),
           'Brand logo component should be created'
    
    logo_content = File.read('app/views/shared/_brand_logo.html.erb')
    assert_includes logo_content, 'brand/logo.svg', 'Should reference logo assets'
    assert_includes logo_content, 'dark:hidden', 'Should include dark mode handling'
  end
  
  def test_stimulus_controller_creation
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    assert File.exist?('app/javascript/controllers/theme_switcher_controller.js'),
           'Theme switcher Stimulus controller should be created'
    
    controller_content = File.read('app/javascript/controllers/theme_switcher_controller.js')
    assert_includes controller_content, 'localStorage.getItem(\'theme\')',
                    'Should handle localStorage persistence'
    assert_includes controller_content, 'applyTheme(theme)',
                    'Should include theme application logic'
    assert_includes controller_content, 'themeChanged',
                    'Should dispatch theme change events'
  end
  
  def test_brand_assets_creation
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    assert File.exist?('app/assets/images/brand/logo.svg'),
           'Default logo SVG should be created'
    assert File.exist?('app/assets/images/brand/logo-dark.svg'),
           'Dark mode logo SVG should be created'
    assert File.exist?('app/assets/images/brand/icon.svg'),
           'Icon SVG should be created'
    
    # Check SVG content is valid
    logo_content = File.read('app/assets/images/brand/logo.svg')
    assert_includes logo_content, '<svg', 'Logo should be valid SVG'
    assert_includes logo_content, 'Your Logo', 'Logo should include placeholder text'
  end
  
  def test_theme_initializer_creation
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    assert File.exist?('config/initializers/theme.rb'),
           'Theme initializer should be created'
    
    initializer_content = File.read('config/initializers/theme.rb')
    assert_includes initializer_content, 'config.theme.default_mode',
                    'Should include default mode configuration'
    assert_includes initializer_content, 'module ThemeHelper',
                    'Should include theme helper module'
    assert_includes initializer_content, 'asset_exists?',
                    'Should include asset existence helper'
  end
  
  def test_css_import_integration
    # Create a basic application.css file
    File.write('app/assets/stylesheets/application.css', <<~CSS)
      /*
       *= require_tree .
       *= require_self
       */
      body { margin: 0; }
    CSS
    
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    app_css_content = File.read('app/assets/stylesheets/application.css')
    assert_includes app_css_content, '@import "_theme_variables"',
                    'Should import theme variables'
    assert_includes app_css_content, '@import "theme"',
                    'Should import theme overrides'
  end
  
  def test_dark_mode_css_variables
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    variables_content = File.read('app/assets/stylesheets/_theme_variables.css')
    
    # Check that dark theme overrides key variables
    dark_theme_section = variables_content[/\[data-theme="dark"\].*?(?=\[data-theme|\z)/m]
    assert dark_theme_section, 'Should have dark theme section'
    
    assert_includes dark_theme_section, '--text-primary:',
                    'Dark theme should override text color'
    assert_includes dark_theme_section, '--bg-primary:',
                    'Dark theme should override background color'
    assert_includes dark_theme_section, '--brand-primary:',
                    'Dark theme should adjust brand colors'
  end
  
  def test_system_theme_detection
    theme_dir = File.expand_path('..', __dir__)
    install_path = File.join(theme_dir, 'install.rb')
    load install_path
    
    variables_content = File.read('app/assets/stylesheets/_theme_variables.css')
    assert_includes variables_content, '@media (prefers-color-scheme: dark)',
                    'Should include system theme detection'
    assert_includes variables_content, '[data-theme="system"]',
                    'Should have system theme selector'
  end

  private

  # Minimal helper to simulate Rails template methods
  def create_file(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def prepend_to_file(path, content)
    if File.exist?(path)
      existing_content = File.read(path)
      File.write(path, content + existing_content)
    end
  end

  def say_status(type, message)
    # Silent for tests
  end
end