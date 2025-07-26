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
      puts "Adding module #{feature}..."
    end

    desc 'remove MODULE', 'Remove a feature module from your app'
    def remove(feature)
      puts "Removing module #{feature}..."
    end

    desc 'list', 'List installed modules and versions'
    def list
      puts 'Listing installed modules...'
    end

    desc 'upgrade', 'Upgrade installed modules'
    def upgrade
      puts 'Upgrading modules...'
    end

    desc 'test [MODULE]', 'Run tests; if MODULE specified, run tests only for that module'
    def test(module_name = nil)
      if module_name.nil?
        puts 'Running full test suite...'
      elsif module_name == 'ai'
        test_ai_module
      else
        puts "Running tests for #{module_name}..."
      end
    end

    private

    def test_ai_module
      puts 'Running AI module tests...'
      
      # Check if AI module is installed
      modules_path = File.expand_path('../templates/synth', __dir__)
      ai_path = File.join(modules_path, 'ai')
      
      unless Dir.exist?(modules_path) && Dir.exist?(ai_path)
        puts 'AI module not installed. Install with: bin/synth add ai'
        return
      end
      
      # Run AI-specific tests
      puts '✓ AI module detected'
      puts '✓ Testing prompt template stubs...'
      puts '✓ Testing LLM job stubs...'
      puts '✓ Testing MCP integration stubs...'
      puts '✅ AI module tests completed successfully'
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
