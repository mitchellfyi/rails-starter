# frozen_string_literal: true

# Create bin/synth CLI
run 'mkdir -p bin'
create_file 'bin/synth', <<~RUBY
  #!/usr/bin/env ruby
  # frozen_string_literal: true

  require 'thor'
  require_relative '../lib/synth/cli'

  Synth::CLI.start(ARGV)
RUBY
run 'chmod +x bin/synth'

# Create CLI implementation
run 'mkdir -p lib/synth'
create_file 'lib/synth/cli.rb', <<~RUBY
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

        puts "\nInstalled modules:"
        installed_modules_path = Rails.root.join('app', 'domains')
        if Dir.exist?(installed_modules_path)
          installed_modules = Dir.children(installed_modules_path).select { |d| File.directory?(File.join(installed_modules_path, d)) }
          if installed_modules.any?
            installed_modules.each do |module_name|
              readme_path = File.join(installed_modules_path, module_name, 'README.md')
              if File.exist?(readme_path)
                first_line = File.readlines(readme_path).first&.strip&.gsub(/^#\s*/, '')
                puts "  ✅ #{module_name.ljust(10)} - #{first_line}"
              else
                puts "  ✅ #{module_name}"
              end
            end
          else
            puts '  (none)'
          end
        else
          puts '  (none)'
        end
      end

      desc 'add MODULE', 'Add a feature module to your app'
      def add(module_name)
        module_template_path = File.join(TEMPLATE_PATH, module_name)
        install_file = File.join(module_template_path, 'install.rb')
        module_domain_path = Rails.root.join('app', 'domains', module_name)

        unless File.exist?(install_file)
          puts "❌ Module installer not found: #{install_file}"
          return
        end

        if Dir.exist?(module_domain_path)
          puts "⚠️  Module '#{module_name}' already exists at #{module_domain_path}. Skipping installation."
          return
        end

        puts "📦 Installing #{module_name} module..."
        
        # Create domain-specific directories
        %w[app/controllers app/models app/services app/jobs app/mailers app/policies app/queries].each do |sub_dir|
          FileUtils.mkdir_p(File.join(module_domain_path, sub_dir))
        end

        # Copy README.md to the new domain directory
        readme_template_path = File.join(module_template_path, 'README.md')
        if File.exist?(readme_template_path)
          FileUtils.cp(readme_template_path, File.join(module_domain_path, 'README.md'))
        end

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
        log_module_action(:add, module_name)
      rescue => e
        puts "❌ Error installing module: #{e.message}"
        puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
        log_module_action(:error, module_name, e.message)
      end

      desc 'upgrade', 'Upgrade all installed modules'
      def upgrade
        puts '🔄 Upgrade functionality not yet implemented. Please update modules manually.'
      end

      desc 'test [MODULE]', 'Run tests for all modules or a specific module'
      def test(module_name = nil)
        if module_name
          module_spec_path = Rails.root.join('spec', 'domains', module_name)
          if Dir.exist?(module_spec_path)
            puts "🧪 Running tests for #{module_name} module..."
            system("bundle exec rspec #{module_spec_path}")
          else
            puts "❌ Test path not found for module: #{module_name}"
          end
        else
          puts '🧪 Running full test suite...'
          system('bundle exec rspec spec/')
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

        # Check modular structure
        puts "\nChecking modular structure:"
        modular_path = Rails.root.join('app', 'domains')
        if Dir.exist?(modular_path)
          puts "✅ app/domains directory exists"
          installed_modules = Dir.children(modular_path).select { |d| File.directory?(File.join(modular_path, d)) }
          if installed_modules.any?
            puts "Installed modules: #{installed_modules.join(', ')}"
          else
            puts "No modules installed in app/domains"
          end
        else
          puts "⚠️  app/domains directory not found"
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

      private

      def log_module_action(action, module_name, message = nil)
        log_file = Rails.root.join('log', 'synth.log')
        FileUtils.mkdir_p(File.dirname(log_file))
        File.open(log_file, 'a') do |f|
          f.puts "[#{Time.current.iso8601}] [#{action.to_s.upcase}] Module: #{module_name} #{" - #{message}" if message}"
        end
      end
    end
  end
RUBY
