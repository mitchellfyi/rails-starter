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
        run_command('bundle exec rspec')
      else
        puts "Running tests for #{feature}..."
        case feature
        when 'ai'
          run_command('bundle exec rspec spec/models/ai spec/requests/ai spec/system/ai')
        when 'auth'
          run_command('bundle exec rspec spec/models/user_spec.rb spec/system/authentication_spec.rb')
        when 'workspaces'
          run_command('bundle exec rspec spec/models/workspace_spec.rb spec/models/membership_spec.rb spec/system/workspace_management_spec.rb')
        when 'billing'
          run_command('bundle exec rspec spec/models/billing spec/requests/billing spec/system/billing')
        when 'admin'
          run_command('bundle exec rspec spec/models/admin spec/system/admin')
        when 'api'
          run_command('bundle exec rspec spec/requests/api')
        when 'system'
          run_command('bundle exec rspec spec/system')
        when 'models'
          run_command('bundle exec rspec spec/models')
        else
          puts "Unknown module: #{feature}"
          puts "Available modules: ai, auth, workspaces, billing, admin, api, system, models"
        end
      end
    end

    private

    def run_command(command)
      system(command) || exit(1)
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
