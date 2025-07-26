# frozen_string_literal: true

require 'thor'
require 'fileutils'

module Synth
  class CLI < Thor
    TEMPLATE_PATH = File.expand_path('../templates/synth', __dir__)

    desc 'list', 'List available and installed modules'
    def list
      puts 'Available modules:'
      
      if Dir.exist?(TEMPLATE_PATH)
        Dir.children(TEMPLATE_PATH).each { |m| puts "  - #{m}" }
      else
        puts '  (none found)'
      end
    end

    desc 'add MODULE', 'Add a feature module to your app'
    def add(module_name)
      module_path = File.join(TEMPLATE_PATH, module_name)
      
      unless Dir.exist?(module_path)
        puts "❌ Module '#{module_name}' not found in #{TEMPLATE_PATH}"
        puts "Available modules: #{Dir.exist?(TEMPLATE_PATH) ? Dir.children(TEMPLATE_PATH).join(', ') : 'none'}"
        exit 1
      end

      installer_path = File.join(module_path, 'install.rb')
      
      unless File.exist?(installer_path)
        puts "❌ Install script not found for '#{module_name}' module"
        exit 1
      end

      puts "🔧 Installing #{module_name} module..."
      
      # Change to app root directory
      app_root = Dir.pwd
      
      # Execute the installer in the context of the Rails app
      begin
        load installer_path
        puts "✅ #{module_name} module installed successfully!"
      rescue StandardError => e
        puts "❌ Error installing #{module_name}: #{e.message}"
        exit 1
      end
    end

    desc 'remove MODULE', 'Remove a feature module from your app'
    def remove(module_name)
      puts "⚠️  Manual removal required for #{module_name} module"
      puts "Please review and remove the following that were added by this module:"
      puts "- Configuration files"
      puts "- Database migrations"
      puts "- Routes"
      puts "- Controllers and models"
      puts "See the module's README for specific removal instructions."
    end

    desc 'upgrade', 'Upgrade all installed modules'
    def upgrade
      puts '🔄 Upgrade functionality not yet implemented'
      puts 'For now, manually check for updates to individual modules'
    end

    desc 'test [MODULE]', 'Run tests for all modules or a specific module'
    def test(module_name = nil)
      if module_name
        puts "🧪 Running tests for #{module_name} module..."
        system("bin/rails test test/#{module_name}/**/*_test.rb") ||
          system("bundle exec rspec spec/#{module_name}/")
      else
        puts '🧪 Running full test suite...'
        system('bin/rails test') || system('bundle exec rspec')
      end
    end

    desc 'doctor', 'Validate setup, configuration, and dependencies'
    def doctor
      puts '🏥 Running system diagnostics...'
      
      # Check Ruby version
      puts "Ruby version: #{RUBY_VERSION}"
      
      # Check Rails
      if system('which rails', out: File::NULL, err: File::NULL)
        rails_version = `rails -v`.strip
        puts "Rails: #{rails_version}"
      else
        puts "❌ Rails not found"
      end
      
      # Check database
      if File.exist?('config/database.yml')
        puts "✅ Database configuration found"
      else
        puts "⚠️  Database configuration missing"
      end
      
      # Check for required gems
      required_gems = %w[pg redis sidekiq devise]
      puts "\nChecking required gems:"
      required_gems.each do |gem|
        if system("bundle show #{gem}", out: File::NULL, err: File::NULL)
          puts "  ✅ #{gem}"
        else
          puts "  ❌ #{gem} missing"
        end
      end
      
      # Check environment files
      if File.exist?('.env.example')
        puts "✅ Environment template found"
      else
        puts "⚠️  .env.example missing"
      end
      
      puts "\n🏥 Diagnostics complete"
    end

    desc 'scaffold TYPE NAME', 'Scaffold new components (e.g., agent chatbot_support)'
    def scaffold(type, name)
      case type
      when 'agent'
        puts "🤖 Scaffolding AI agent: #{name}"
        # This would scaffold a new AI agent with prompts, controllers, etc.
        puts "TODO: Implement agent scaffolding"
      else
        puts "❌ Unknown scaffold type: #{type}"
        puts "Available types: agent"
      end
    end
  end
end
