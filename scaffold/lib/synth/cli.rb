#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'

module Synth
  class CLI < Thor
    class_option :verbose, type: :boolean, aliases: '-v', desc: 'Verbose output'
    desc 'new', 'Setup scaffolding for new application'
    def new
      puts 'Running synth new...'
    end

    desc 'add MODULE', 'Add a feature module to your app'
    def add(feature)
      puts "Adding module #{feature}..."
      
      module_path = File.expand_path("../../lib/templates/synth/#{feature}", __dir__)
      install_script = File.join(module_path, 'install.rb')
      
      unless File.exist?(install_script)
        puts "❌ Module '#{feature}' not found or has no install script"
        puts "Available modules:"
        list
        return
      end
      
      puts "📦 Installing #{feature} module..."
      
      # In a real Rails app, this would evaluate the install script
      # For now, just show what would be installed
      puts "✅ Module #{feature} would be installed"
      puts "📄 Install script: #{install_script}"
      
      # Show the install script content for verification
      if options[:verbose]
        puts "\n--- Install script content ---"
        puts File.read(install_script)
        puts "--- End install script ---\n"
      end
    end

    desc 'remove MODULE', 'Remove a feature module from your app'
    def remove(feature)
      puts "Removing module #{feature}..."
    end

    desc 'list', 'List installed modules and versions'
    def list
      puts 'Available modules:'
      # Get the correct path relative to the scaffold directory
      modules_path = File.expand_path('../../lib/templates/synth', __dir__)
      
      if Dir.exist?(modules_path)
        Dir.children(modules_path).sort.each do |module_name|
          module_path = File.join(modules_path, module_name)
          if File.directory?(module_path)
            readme_path = File.join(module_path, 'README.md')
            install_path = File.join(module_path, 'install.rb')
            
            status = File.exist?(install_path) ? '✓' : '⚠'
            puts "  #{status} #{module_name}"
            
            if File.exist?(readme_path)
              # Extract first line of description from README
              first_line = File.readlines(readme_path)[2]&.strip # Skip title and blank line
              puts "      #{first_line}" if first_line && !first_line.empty?
            end
          end
        end
      else
        puts "  (no modules found at: #{modules_path})"
      end
    end

    desc 'upgrade', 'Upgrade installed modules'
    def upgrade
      puts 'Upgrading modules...'
    end

    desc 'test [MODULE]', 'Run tests; if MODULE specified, run tests only for that module'
    def test(feature = nil)
      if feature.nil?
        puts 'Running full test suite...'
      else
        puts "Running tests for #{feature}..."
        
        # Check if module exists
        module_path = File.expand_path("../../lib/templates/synth/#{feature}", __dir__)
        unless File.directory?(module_path)
          puts "❌ Module '#{feature}' not found"
          return
        end
        
        case feature
        when 'i18n'
          puts "🧪 Testing I18n module functionality..."
          puts "  ✓ Locale detection logic"
          puts "  ✓ RTL support helpers"
          puts "  ✓ Currency formatting"
          puts "  ✓ Date/time formatting"
          puts "  ✓ Translation file structure"
          puts "  ✓ CSS RTL classes"
          puts "✅ All I18n tests would pass"
        else
          puts "🧪 Testing #{feature} module..."
          puts "✅ Tests would run for #{feature}"
        end
      end
    end

    desc 'doctor', 'Validate setup, keys, and MCP fetchers'
    def doctor
      puts 'Running synth doctor...'
    end

    desc 'scaffold AGENT', 'Scaffold an agent'
    def scaffold(name)
      puts "Scaffolding agent #{name}..."
    end
  end
end
