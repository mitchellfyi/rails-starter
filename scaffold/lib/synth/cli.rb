# frozen_string_literal: true

require 'thor'
require 'fileutils'

module Synth
  class CLI < Thor
    TEMPLATE_PATH = File.expand_path('../templates/synth', __dir__)

    desc 'list', 'List available modules'
    def list
      puts 'Available modules:'
      
      if Dir.exist?(TEMPLATE_PATH)
        modules = Dir.children(TEMPLATE_PATH).select { |d| File.directory?(File.join(TEMPLATE_PATH, d)) }
        modules.each do |module_name|
          readme_path = File.join(TEMPLATE_PATH, module_name, 'README.md')
          if File.exist?(readme_path)
            first_line = File.readlines(readme_path).first&.strip&.gsub(/^#\s*/, '')
            puts "  #{module_name.ljust(10)} - #{first_line}"
          else
            puts "  #{module_name}"
          end
        end
      else
        puts '  (none found)'
      end
    end

    desc 'add MODULE', 'Add a feature module to your app'
    def add(module_name)
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