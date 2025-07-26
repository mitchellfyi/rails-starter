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
    def add(feature)
      templates_path = File.join(__dir__, '..', 'templates', 'synth')
      module_path = File.join(templates_path, feature)
      install_script = File.join(module_path, 'install.rb')
      
      unless Dir.exist?(module_path)
        puts "Error: Module '#{feature}' not found in #{templates_path}"
        return
      end
      
      unless File.exist?(install_script)
        puts "Error: Install script not found for module '#{feature}'"
        return
      end
      
      puts "Installing module: #{feature}"
      puts "Install script found at: #{install_script}"
      puts "Note: This would normally execute the Rails template installer"
      puts "Run the following in a Rails app to install:"
      puts "  rails app:template LOCATION=#{install_script}"
    end

    desc 'remove MODULE', 'Remove a feature module from your app'
    def remove(feature)
      puts "Removing module #{feature}..."
    end

    desc 'list', 'List available modules'
    def list
      templates_path = File.join(__dir__, '..', 'templates', 'synth')
      puts 'Available modules:'
      
      if Dir.exist?(templates_path)
        Dir.children(templates_path).each { |m| puts "  - #{m}" }
      else
        puts '  (none found)'
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
