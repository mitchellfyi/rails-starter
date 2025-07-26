# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'json'
require 'pathname'

module Synth
  class CLI < Thor
    TEMPLATE_PATH = File.expand_path('../../scaffold/lib/templates/synth', __dir__)
    REGISTRY_PATH = File.expand_path('../../scaffold/config/synth_modules.json', __dir__)
    
    class_option :verbose, type: :boolean, aliases: '-v', desc: 'Enable verbose output'

    desc 'list', 'List available and installed modules'
    method_option :available, type: :boolean, aliases: '-a', desc: 'Show only available modules'
    method_option :installed, type: :boolean, aliases: '-i', desc: 'Show only installed modules'
    def list
      if options[:installed]
        show_installed_modules
      elsif options[:available]
        show_available_modules  
      else
        show_available_modules
        puts ""
        show_installed_modules
      end
    end

    desc 'add MODULE', 'Install a feature module'
    method_option :force, type: :boolean, aliases: '-f', desc: 'Force reinstall if already installed'
    def add(module_name)
      module_template_path = File.join(TEMPLATE_PATH, module_name)
      
      unless Dir.exist?(module_template_path)
        puts "❌ Module '#{module_name}' not found in templates"
        show_available_modules
        exit 1
      end

      if module_installed?(module_name) && !options[:force]
        puts "⚠️  Module '#{module_name}' is already installed. Use --force to reinstall."
        exit 1
      end

      install_module(module_name, module_template_path)
    end

    desc 'remove MODULE', 'Uninstall a feature module'
    method_option :force, type: :boolean, aliases: '-f', desc: 'Force removal without confirmation'
    def remove(module_name)
      unless module_installed?(module_name)
        puts "❌ Module '#{module_name}' is not installed"
        show_installed_modules
        exit 1
      end

      unless options[:force]
        print "Are you sure you want to remove '#{module_name}'? This will delete files and may cause data loss. [y/N]: "
        confirmation = STDIN.gets.chomp.downcase
        unless confirmation == 'y' || confirmation == 'yes'
          puts "❌ Module removal cancelled"
          exit 1
        end
      end

      remove_module(module_name)
    end

    desc 'upgrade [MODULE]', 'Upgrade one or all installed modules'
    def upgrade(module_name = nil)
      if module_name
        upgrade_single_module(module_name)
      else
        upgrade_all_modules
      end
    end

    desc 'test [MODULE]', 'Run tests for a specific module or all modules'
    def test(module_name = nil)
      if module_name
        test_single_module(module_name)
      else
        test_all_modules
      end
    end

    desc 'doctor', 'Validate setup, configuration, and dependencies'
    def doctor
      puts '🏥 Running system diagnostics...'
      
      results = []
      results << check_ruby_version
      results << check_rails
      results << check_database_config
      results << check_required_gems
      results << check_environment_files
      results << check_modular_structure
      results << check_registry_integrity
      
      puts "\n🏥 Diagnostics complete"
      
      failed_checks = results.count(false)
      if failed_checks > 0
        puts "❌ #{failed_checks} check(s) failed"
        exit 1
      else
        puts "✅ All checks passed"
      end
    end

    desc 'info MODULE', 'Show detailed information about a module'
    def info(module_name)
      show_module_info(module_name)
    end

    desc 'scaffold TYPE NAME', 'Scaffold new components'
    def scaffold(type, name)
      case type
      when 'agent'
        puts "🤖 Scaffolding AI agent: #{name}"
        puts "TODO: Implement agent scaffolding"
      else
        puts "❌ Unknown scaffold type: #{type}"
        puts "Available types: agent"
      end
    end

    private

    def show_available_modules
      puts '📦 Available modules:'
      
      unless Dir.exist?(TEMPLATE_PATH)
        puts '  (templates directory not found)'
        return
      end

      modules = Dir.children(TEMPLATE_PATH).select { |d| File.directory?(File.join(TEMPLATE_PATH, d)) }
      
      if modules.empty?
        puts '  (no modules found)'
        return
      end

      modules.sort.each do |module_name|
        module_path = File.join(TEMPLATE_PATH, module_name)
        readme_path = File.join(module_path, 'README.md')
        version_path = File.join(module_path, 'VERSION')
        
        description = if File.exist?(readme_path)
          File.readlines(readme_path).first&.strip&.gsub(/^#\s*/, '') || 'No description'
        else
          'No description'
        end
        
        version = if File.exist?(version_path)
          File.read(version_path).strip
        else
          'unknown'
        end
        
        installed = module_installed?(module_name)
        status_icon = installed ? '✅' : '  '
        
        puts "  #{status_icon} #{module_name.ljust(15)} v#{version.ljust(8)} - #{description}"
      end
    end

    def show_installed_modules
      puts '🔧 Installed modules:'
      
      registry = load_registry
      installed_modules = registry['installed'] || {}
      
      if installed_modules.empty?
        puts '  (no modules installed)'
        return
      end

      installed_modules.each do |module_name, info|
        version = info['version'] || 'unknown'
        installed_at = info['installed_at'] ? Time.parse(info['installed_at']).strftime('%Y-%m-%d') : 'unknown'
        puts "  ✅ #{module_name.ljust(15)} v#{version.ljust(8)} (installed: #{installed_at})"
      end
    end

    def install_module(module_name, module_template_path)
      puts "📦 Installing #{module_name} module..."
      
      install_file = File.join(module_template_path, 'install.rb')
      
      unless File.exist?(install_file)
        puts "❌ Module installer not found: #{install_file}"
        exit 1
      end

      begin
        # Load version info
        version_path = File.join(module_template_path, 'VERSION')
        version = File.exist?(version_path) ? File.read(version_path).strip : '1.0.0'
        
        # Execute the installer
        puts "  Running installer script..." if options[:verbose]
        load_and_execute_installer(install_file)
        
        # Update registry
        update_registry(module_name, {
          'version' => version,
          'installed_at' => Time.current.iso8601,
          'template_path' => module_template_path
        })
        
        # Auto-patch configurations
        auto_patch_configurations(module_name, module_template_path)
        
        puts "✅ Successfully installed #{module_name} module!"
        log_module_action(:install, module_name, version)
        
      rescue StandardError => e
        puts "❌ Error installing module: #{e.message}"
        puts e.backtrace.first(5).join("\n") if options[:verbose]
        log_module_action(:error, module_name, e.message)
        exit 1
      end
    end

    def remove_module(module_name)
      puts "🗑️  Removing #{module_name} module..."
      
      registry = load_registry
      module_info = registry.dig('installed', module_name)
      
      unless module_info
        puts "❌ Module not found in registry"
        exit 1
      end

      begin
        # Look for remove script
        template_path = module_info['template_path']
        remove_file = File.join(template_path, 'remove.rb') if template_path
        
        if remove_file && File.exist?(remove_file)
          puts "  Running removal script..." if options[:verbose]
          load_and_execute_installer(remove_file)
        else
          # Default removal logic
          default_module_removal(module_name)
        end
        
        # Remove from registry
        registry['installed'].delete(module_name)
        save_registry(registry)
        
        puts "✅ Successfully removed #{module_name} module!"
        log_module_action(:remove, module_name)
        
      rescue StandardError => e
        puts "❌ Error removing module: #{e.message}"
        puts e.backtrace.first(5).join("\n") if options[:verbose]
        log_module_action(:error, module_name, e.message)
        exit 1
      end
    end

    def upgrade_single_module(module_name)
      unless module_installed?(module_name)
        puts "❌ Module '#{module_name}' is not installed"
        exit 1
      end
      
      puts "🔄 Upgrading #{module_name} module..."
      # Force reinstall to upgrade
      add(module_name, force: true)
    end

    def upgrade_all_modules
      registry = load_registry
      installed_modules = registry['installed'] || {}
      
      if installed_modules.empty?
        puts "📦 No modules installed to upgrade"
        return
      end
      
      puts "🔄 Upgrading all installed modules..."
      installed_modules.keys.each do |module_name|
        upgrade_single_module(module_name)
      end
    end

    def test_single_module(module_name)
      unless module_installed?(module_name)
        puts "❌ Module '#{module_name}' is not installed"
        exit 1
      end
      
      # Look for module-specific tests
      test_paths = [
        "spec/domains/#{module_name}",
        "test/domains/#{module_name}",
        "spec/#{module_name}",
        "test/#{module_name}"
      ]
      
      test_path = test_paths.find { |path| Dir.exist?(path) }
      
      if test_path
        puts "🧪 Running tests for #{module_name} module..."
        if test_path.start_with?('spec/')
          system("bundle exec rspec #{test_path}")
        else
          system("bundle exec rails test #{test_path}")
        end
      else
        puts "❌ No tests found for module: #{module_name}"
        exit 1
      end
    end

    def test_all_modules
      puts '🧪 Running full test suite...'
      
      # Try RSpec first, then fall back to Minitest
      if File.exist?('spec/rails_helper.rb')
        system('bundle exec rspec')
      elsif File.exist?('test/test_helper.rb')
        system('bundle exec rails test')
      else
        puts "❌ No test framework detected"
        exit 1
      end
    end

    def show_module_info(module_name)
      module_template_path = File.join(TEMPLATE_PATH, module_name)
      
      unless Dir.exist?(module_template_path)
        puts "❌ Module '#{module_name}' not found"
        exit 1
      end

      puts "📋 Module: #{module_name}"
      puts "=" * 50
      
      # Basic info
      readme_path = File.join(module_template_path, 'README.md')
      if File.exist?(readme_path)
        puts "\n📖 Description:"
        puts File.read(readme_path).lines.first(5).join
      end
      
      # Version
      version_path = File.join(module_template_path, 'VERSION')
      if File.exist?(version_path)
        puts "\n🏷️  Version: #{File.read(version_path).strip}"
      end
      
      # Installation status
      if module_installed?(module_name)
        registry = load_registry
        info = registry.dig('installed', module_name)
        puts "\n✅ Status: Installed"
        puts "   Installed version: #{info['version']}" if info['version']
        puts "   Installed at: #{info['installed_at']}" if info['installed_at']
      else
        puts "\n❌ Status: Not installed"
      end
      
      # Files
      puts "\n📁 Files:"
      Dir.glob(File.join(module_template_path, "**/*")).each do |file|
        next if File.directory?(file)
        relative_path = Pathname.new(file).relative_path_from(Pathname.new(module_template_path))
        puts "   #{relative_path}"
      end
    end

    def module_installed?(module_name)
      registry = load_registry
      registry.dig('installed', module_name) != nil
    end

    def load_registry
      return { 'installed' => {} } unless File.exist?(REGISTRY_PATH)
      
      begin
        JSON.parse(File.read(REGISTRY_PATH))
      rescue JSON::ParserError
        puts "⚠️  Registry file corrupted, resetting..." if options[:verbose]
        { 'installed' => {} }
      end
    end

    def save_registry(registry)
      FileUtils.mkdir_p(File.dirname(REGISTRY_PATH))
      File.write(REGISTRY_PATH, JSON.pretty_generate(registry))
    end

    def update_registry(module_name, info)
      registry = load_registry
      registry['installed'] ||= {}
      registry['installed'][module_name] = info
      save_registry(registry)
    end

    def load_and_execute_installer(install_file)
      # Set up Rails environment if not already loaded
      unless defined?(Rails)
        require_relative '../config/environment'
      end
      
      # Load and execute the installer in the context of a Rails generator
      require 'rails/generators'
      require 'rails/generators/base'
      
      generator_class = Class.new(Rails::Generators::Base) do
        include Rails::Generators::Actions
        
        def self.source_root
          Rails.root
        end
      end
      
      generator = generator_class.new
      generator.instance_eval(File.read(install_file))
    end

    def auto_patch_configurations(module_name, module_template_path)
      puts "  Auto-patching configurations..." if options[:verbose]
      
      # Patch routes if routes file exists
      routes_patch_path = File.join(module_template_path, 'config', 'routes.rb')
      if File.exist?(routes_patch_path)
        patch_routes(routes_patch_path)
      end
      
      # Patch application configuration
      app_config_patch_path = File.join(module_template_path, 'config', 'application.rb')
      if File.exist?(app_config_patch_path)
        patch_application_config(app_config_patch_path)
      end
      
      # Run migrations if present
      migrations_dir = File.join(module_template_path, 'db', 'migrate')
      if Dir.exist?(migrations_dir)
        copy_and_run_migrations(migrations_dir)
      end
      
      # Load seeds if present
      seeds_file = File.join(module_template_path, 'db', 'seeds.rb')
      if File.exist?(seeds_file)
        patch_seeds(seeds_file)
      end
    end

    def patch_routes(routes_patch_path)
      routes_file = 'config/routes.rb'
      return unless File.exist?(routes_file)
      
      patch_content = File.read(routes_patch_path)
      routes_content = File.read(routes_file)
      
      # Insert routes before the final 'end'
      unless routes_content.include?(patch_content.strip)
        updated_content = routes_content.sub(/^end\s*$/, "#{patch_content}\nend")
        File.write(routes_file, updated_content)
        puts "    ✅ Patched routes.rb" if options[:verbose]
      end
    end

    def patch_application_config(app_config_patch_path)
      app_config_file = 'config/application.rb'
      return unless File.exist?(app_config_file)
      
      patch_content = File.read(app_config_patch_path)
      app_config_content = File.read(app_config_file)
      
      # Insert config before the final 'end' of the Application class
      unless app_config_content.include?(patch_content.strip)
        updated_content = app_config_content.sub(
          /(class Application.*?)\n(\s+)end\s*end\s*$/m,
          "\\1\n\\2#{patch_content}\n\\2end\nend"
        )
        File.write(app_config_file, updated_content)
        puts "    ✅ Patched application.rb" if options[:verbose]
      end
    end

    def copy_and_run_migrations(migrations_dir)
      timestamp = Time.current.strftime("%Y%m%d%H%M%S")
      
      Dir.glob(File.join(migrations_dir, "*.rb")).each_with_index do |migration_file, index|
        migration_name = File.basename(migration_file)
        new_timestamp = (timestamp.to_i + index).to_s
        new_name = migration_name.sub(/^\d+/, new_timestamp)
        
        target_path = File.join('db', 'migrate', new_name)
        
        unless File.exist?(target_path)
          FileUtils.cp(migration_file, target_path)
          puts "    ✅ Copied migration: #{new_name}" if options[:verbose]
        end
      end
      
      # Run migrations
      system('bundle exec rails db:migrate')
    end

    def patch_seeds(seeds_file)
      main_seeds_file = 'db/seeds.rb'
      
      unless File.exist?(main_seeds_file)
        File.write(main_seeds_file, "# Application seeds\n")
      end
      
      seeds_content = File.read(main_seeds_file)
      patch_content = File.read(seeds_file)
      
      unless seeds_content.include?(patch_content.strip)
        File.write(main_seeds_file, "#{seeds_content}\n#{patch_content}\n")
        puts "    ✅ Patched seeds.rb" if options[:verbose]
      end
    end

    def default_module_removal(module_name)
      # Remove from app/domains if it exists
      domains_path = File.join('app', 'domains', module_name)
      if Dir.exist?(domains_path)
        FileUtils.rm_rf(domains_path)
        puts "    🗑️  Removed #{domains_path}" if options[:verbose]
      end
      
      # Remove from spec/domains if it exists
      spec_path = File.join('spec', 'domains', module_name)
      if Dir.exist?(spec_path)
        FileUtils.rm_rf(spec_path)
        puts "    🗑️  Removed #{spec_path}" if options[:verbose]
      end
      
      # Remove from test/domains if it exists
      test_path = File.join('test', 'domains', module_name)
      if Dir.exist?(test_path)
        FileUtils.rm_rf(test_path)
        puts "    🗑️  Removed #{test_path}" if options[:verbose]
      end
    end

    def check_ruby_version
      puts "Ruby version: #{RUBY_VERSION}"
      true # Ruby is running, so version is adequate
    end

    def check_rails
      if system('which rails', out: File::NULL, err: File::NULL)
        rails_version = `rails -v`.strip
        puts "Rails: #{rails_version}"
        true
      else
        puts "❌ Rails not found"
        false
      end
    end

    def check_database_config
      if File.exist?('config/database.yml')
        puts "✅ Database configuration found"
        true
      else
        puts "⚠️  Database configuration missing"
        false
      end
    end

    def check_required_gems
      required_gems = %w[thor fileutils json]
      puts "\nChecking required gems:"
      
      all_present = true
      required_gems.each do |gem|
        begin
          require gem
          puts "  ✅ #{gem}"
        rescue LoadError
          puts "  ❌ #{gem} missing"
          all_present = false
        end
      end
      all_present
    end

    def check_environment_files
      if File.exist?('.env.example')
        puts "✅ Environment template found"
        true
      else
        puts "⚠️  .env.example missing"
        false
      end
    end

    def check_modular_structure
      puts "\nChecking modular structure:"
      
      if File.exist?(REGISTRY_PATH)
        puts "✅ Module registry found"
        registry_ok = true
      else
        puts "⚠️  Module registry not found at #{REGISTRY_PATH}"
        registry_ok = false
      end
      
      if Dir.exist?(TEMPLATE_PATH)
        puts "✅ Module templates directory found"
        templates_ok = true
      else
        puts "⚠️  Module templates directory not found at #{TEMPLATE_PATH}"
        templates_ok = false
      end
      
      registry_ok && templates_ok
    end

    def check_registry_integrity
      return true unless File.exist?(REGISTRY_PATH)
      
      begin
        registry = JSON.parse(File.read(REGISTRY_PATH))
        puts "✅ Module registry is valid JSON"
        
        installed_count = registry.dig('installed')&.keys&.count || 0
        puts "📦 #{installed_count} module(s) registered as installed"
        true
      rescue JSON::ParserError
        puts "❌ Module registry is corrupted (invalid JSON)"
        false
      end
    end

    def log_module_action(action, module_name, message = nil)
      log_file = 'log/synth.log'
      FileUtils.mkdir_p(File.dirname(log_file))
      
      File.open(log_file, 'a') do |f|
        timestamp = Time.current.iso8601
        log_message = "[#{timestamp}] [#{action.to_s.upcase}] Module: #{module_name}"
        log_message += " - #{message}" if message
        f.puts log_message
      end
    end
  end
end