#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'

module Synth
  class CLI < Thor
    desc 'new', 'Setup scaffolding for new application'
    long_desc <<~DESC
      Initialize a new Rails application with the SaaS Starter Template.
      This command sets up the base stack including authentication, background jobs,
      and workspace/team models.

      Examples:
        bin/synth new
    DESC
    def new
      puts 'Running synth new...'
    end

    desc 'add MODULE', 'Add a feature module to your app'
    long_desc <<~DESC
      Install a feature module into your Rails application. Available modules
      include ai, billing, cms, admin, and others.

      The module installer will:
      - Add necessary gems to your Gemfile
      - Run database migrations
      - Copy configuration files
      - Set up routes and controllers
      - Install tests

      Examples:
        bin/synth add ai          # Add AI/LLM integration
        bin/synth add billing     # Add Stripe billing
        bin/synth add cms         # Add CMS/blog engine
        bin/synth add admin       # Add admin panel
    DESC
    def add(feature)
      puts "Adding module #{feature}..."
    end

    desc 'remove MODULE', 'Remove a feature module from your app'
    long_desc <<~DESC
      Remove a previously installed feature module from your application.
      This will clean up files, routes, and database changes where possible.

      Warning: This may remove data. Always backup your database first.

      Examples:
        bin/synth remove cms      # Remove CMS/blog engine
        bin/synth remove billing  # Remove billing integration
    DESC
    def remove(feature)
      puts "Removing module #{feature}..."
    end

    desc 'list', 'List installed modules and versions'
    long_desc <<~DESC
      Display all currently installed modules and their versions.
      This helps you track which features are active in your application.

      Examples:
        bin/synth list
    DESC
    def list
      puts 'Listing installed modules...'
    end

    desc 'upgrade', 'Upgrade installed modules'
    long_desc <<~DESC
      Update all installed modules to their latest versions.
      This will pull in bug fixes and new features while preserving
      your customizations.

      Examples:
        bin/synth upgrade         # Upgrade all modules
    DESC
    def upgrade
      puts 'Upgrading modules...'
    end

    desc 'test [MODULE]', 'Run tests; if MODULE specified, run tests only for that module'
    long_desc <<~DESC
      Execute the test suite for your application or a specific module.
      This runs the appropriate test framework (RSpec or Minitest) and
      ensures all features work correctly.

      Examples:
        bin/synth test            # Run all tests
        bin/synth test ai         # Run only AI module tests
        bin/synth test billing    # Run only billing tests
    DESC
    def test(feature = nil)
      if feature.nil?
        puts 'Running full test suite...'
      else
        puts "Running tests for #{feature}..."
      end
    end

    desc 'doctor', 'Validate setup, keys, and MCP fetchers'
    long_desc <<~DESC
      Run diagnostics to ensure your application is properly configured.
      This checks:
      - Database connectivity
      - Required API keys and credentials
      - MCP (Multi-Context Provider) fetchers
      - Background job processing
      - External service integrations

      Examples:
        bin/synth doctor
    DESC
    def doctor
      puts 'Running synth doctor...'
    end

    desc 'scaffold AGENT NAME', 'Scaffold a new AI agent'
    long_desc <<~DESC
      Generate a new AI agent with prompt templates, job handlers, and tests.
      This creates the boilerplate code needed for AI-powered features.

      Examples:
        bin/synth scaffold agent chatbot_support
        bin/synth scaffold agent email_generator
        bin/synth scaffold agent code_reviewer
    DESC
    def scaffold(type, name = nil)
      if type == 'agent' && name
        puts "Scaffolding agent #{name}..."
      else
        puts "Usage: bin/synth scaffold agent NAME"
      end
    end
  end
end
