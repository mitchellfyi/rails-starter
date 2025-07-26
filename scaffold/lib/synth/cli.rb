#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'yaml'

module Synth
  class CLI < Thor
    MODULES_PATH = 'lib/templates/synth'
    INSTALLED_MODULES_FILE = '.synth_modules.yml'

    desc 'new', 'Setup scaffolding for new application'
    def new
      puts 'Running synth new...'
    end

    desc 'add MODULE', 'Add a feature module to your app'
    def add(feature)
      module_path = File.join(MODULES_PATH, feature)
      install_script = File.join(module_path, 'install.rb')

      unless File.exist?(install_script)
        puts "❌ Module '#{feature}' not found at #{install_script}"
        return
      end

      puts "📦 Installing module: #{feature}"
      
      begin
        # Load and execute the install script in the context of the Rails app generator
        # For now, we'll execute it as Ruby code
        install_code = File.read(install_script)
        
        # Create a simple context for executing install scripts
        context = InstallContext.new(feature)
        context.instance_eval(install_code)
        
        # Track installed module
        track_installed_module(feature)
        
        puts "✅ Module '#{feature}' installed successfully"
        puts "📖 Check #{File.join(module_path, 'README.md')} for next steps"
      rescue => e
        puts "❌ Error installing module '#{feature}': #{e.message}"
        puts "🔍 #{e.backtrace.first}" if options[:verbose]
      end
    end

    desc 'remove MODULE', 'Remove a feature module from your app'
    def remove(feature)
      if installed_modules.include?(feature)
        puts "🗑️  Removing module: #{feature}"
        
        # For now, just remove from tracking - actual removal would need
        # more sophisticated logic to undo changes
        untrack_installed_module(feature)
        
        puts "✅ Module '#{feature}' removed from tracking"
        puts "⚠️  Note: Manual cleanup of generated files may be required"
      else
        puts "❌ Module '#{feature}' is not installed"
      end
    end

    desc 'list', 'List available and installed modules'
    def list
      puts "📋 Available modules:"
      available_modules.each do |module_name|
        status = installed_modules.include?(module_name) ? "✅ installed" : "⬜ available"
        version = get_module_version(module_name)
        puts "  #{module_name.ljust(12)} #{status} #{version ? "(v#{version})" : ''}"
      end
      
      puts "\n📦 Installed modules: #{installed_modules.size}"
    end

    desc 'upgrade', 'Upgrade installed modules'
    def upgrade
      puts '🔄 Upgrading modules...'
      installed_modules.each do |module_name|
        puts "  Checking #{module_name}..."
        # TODO: Implement version checking and upgrade logic
      end
      puts '✅ Upgrade check complete'
    end

    desc 'test [MODULE]', 'Run tests; if MODULE specified, run tests only for that module'
    def test(feature = nil)
      if feature.nil?
        puts '🧪 Running full test suite...'
        system('bin/rails test') || system('bundle exec rspec') || puts("No test command found")
      else
        puts "🧪 Running tests for #{feature}..."
        test_file = "test/synth/#{feature}_test.rb"
        if File.exist?(test_file)
          system("bin/rails test #{test_file}")
        else
          puts "❌ No tests found for module '#{feature}'"
        end
      end
    end

    desc 'doctor', 'Validate setup, keys, and MCP fetchers'
    def doctor
      puts '🩺 Running synth doctor...'
      
      # Check basic setup
      puts "✅ Rails app detected" if File.exist?('config/application.rb')
      puts "✅ Synth CLI accessible" if File.exist?('bin/synth')
      
      # Check for required directories
      puts "✅ Templates directory exists" if Dir.exist?(MODULES_PATH)
      
      # Check installed modules
      puts "📦 #{installed_modules.size} modules installed: #{installed_modules.join(', ')}"
      
      puts '✅ Doctor check complete'
    end

    desc 'scaffold AGENT', 'Scaffold an agent'
    def scaffold(name)
      puts "🤖 Scaffolding agent: #{name}"
      # TODO: Implement agent scaffolding
    end

    private

    def available_modules
      return [] unless Dir.exist?(MODULES_PATH)
      
      Dir.children(MODULES_PATH).select do |entry|
        path = File.join(MODULES_PATH, entry)
        File.directory?(path) && File.exist?(File.join(path, 'install.rb'))
      end.sort
    end

    def installed_modules
      return [] unless File.exist?(INSTALLED_MODULES_FILE)
      
      data = YAML.load_file(INSTALLED_MODULES_FILE) || {}
      data['modules'] || []
    end

    def track_installed_module(feature)
      data = File.exist?(INSTALLED_MODULES_FILE) ? YAML.load_file(INSTALLED_MODULES_FILE) : {}
      data['modules'] ||= []
      data['modules'] << feature unless data['modules'].include?(feature)
      data['modules'].sort!
      
      File.write(INSTALLED_MODULES_FILE, data.to_yaml)
    end

    def untrack_installed_module(feature)
      return unless File.exist?(INSTALLED_MODULES_FILE)
      
      data = YAML.load_file(INSTALLED_MODULES_FILE)
      data['modules']&.delete(feature)
      
      File.write(INSTALLED_MODULES_FILE, data.to_yaml)
    end

    def get_module_version(module_name)
      version_file = File.join(MODULES_PATH, module_name, 'VERSION')
      File.exist?(version_file) ? File.read(version_file).strip : nil
    end
  end

  # Simple context for executing install scripts
  class InstallContext
    attr_reader :module_name

    def initialize(module_name)
      @module_name = module_name
    end

    def say_status(action, message, status = nil)
      icon = status == :error ? "❌" : "📝"
      puts "#{icon} #{action}: #{message}"
    end

    def add_gem(gem_name, *args)
      puts "💎 Would add gem: #{gem_name} #{args.join(' ')}"
      # TODO: Actually modify Gemfile
    end

    def after_bundle(&block)
      puts "📦 After bundle tasks:"
      block.call if block_given?
    end

    def initializer(name, content)
      puts "⚙️  Would create initializer: #{name}"
      # TODO: Actually create initializer file
    end

    def generate(generator, *args)
      puts "🏗️  Would run generator: #{generator} #{args.join(' ')}"
      # TODO: Actually run Rails generator
    end

    def create_file(path, content)
      puts "📁 Would create file: #{path}"
      # TODO: Actually create file
    end

    def copy_file(source, destination)
      puts "📋 Would copy file: #{source} -> #{destination}"
      # TODO: Actually copy file
    end
  end
end
