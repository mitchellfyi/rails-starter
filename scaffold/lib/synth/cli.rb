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
    end

    desc 'scaffold AGENT', 'Scaffold an agent'
    def scaffold(name)
      puts "Scaffolding agent #{name}..."
    end
  end
end
