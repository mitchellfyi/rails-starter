#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'

module Synth
  class CLI < Thor
    desc 'new', 'Setup scaffolding for new application'
    def new
      puts 'Running synth new...'
    end

    desc 'add MODULE', 'Add a feature module to your app'
    def add(module_name)
      available_modules = %w[ai api billing cms admin]
      
      unless available_modules.include?(module_name)
        puts "❌ Unknown module: #{module_name}"
        puts "Available modules: #{available_modules.join(', ')}"
        return
      end

      module_path = File.expand_path("../templates/synth/#{module_name}", __dir__)
      install_file = File.join(module_path, 'install.rb')

      unless File.exist?(install_file)
        puts "❌ Module installer not found: #{install_file}"
        return
      end

      puts "📦 Installing #{module_name} module..."
      
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
      
      puts "✅ Successfully installed #{module_name} module!"
    rescue => e
      puts "❌ Error installing module: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
    end

    desc 'remove MODULE', 'Remove a feature module from your app'
    def remove(feature)
      puts "Removing module #{feature}..."
    end

    desc 'list', 'List installed modules and versions'
    def list
      templates_path = File.expand_path('../templates/synth', __dir__)
      puts 'Available modules:'
      
      if Dir.exist?(templates_path)
        modules = Dir.children(templates_path).select { |d| File.directory?(File.join(templates_path, d)) }
        modules.each do |module_name|
          readme_path = File.join(templates_path, module_name, 'README.md')
          if File.exist?(readme_path)
            first_line = File.readlines(readme_path).first&.strip&.gsub(/^#\s*/, '')
            puts "  #{module_name.ljust(10)} - #{first_line}"
          else
            puts "  #{module_name}"
          end
        end
      else
        puts '  (none found - run from Rails app root)'
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
