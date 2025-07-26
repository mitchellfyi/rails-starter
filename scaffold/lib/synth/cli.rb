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
      
      # Check if we're in a Rails app
      unless File.exist?('config/application.rb')
        puts '❌ Not in a Rails application directory'
        return
      end
      
      # Check environment configuration
      puts '🔍 Checking environment configuration...'
      system('rails deploy:validate_env') if File.exist?('lib/tasks/deploy.rake')
      
      # Check database connection
      puts '🔍 Checking database connection...'
      system('rails deploy:check_db') if File.exist?('lib/tasks/deploy.rake')
      
      # Check Redis connection
      puts '🔍 Checking Redis connection...'
      system('rails deploy:check_redis') if File.exist?('lib/tasks/deploy.rake')
      
      puts '✅ Doctor check completed!'
    end

    desc 'scaffold AGENT', 'Scaffold an agent'
    def scaffold(name)
      puts "Scaffolding agent #{name}..."
    end
  end
end
